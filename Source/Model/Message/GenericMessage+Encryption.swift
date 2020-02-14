//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
import WireCryptobox

private var zmLog = ZMSLog(tag: "message encryption")

extension GenericMessage {
    public func encryptedMessagePayloadData(_ conversation: ZMConversation, externalData: Data?) -> (data: Data, strategy: MissingClientsStrategy)? {
        guard let context = conversation.managedObjectContext else { return nil }
        
        let recipientsAndStrategy = recipientUsersForMessage(in: conversation, selfUser: ZMUser.selfUser(in: context))
        if let data = encryptedMessagePayloadData(for: recipientsAndStrategy.users, externalData: nil, context: context) {
            return (data, recipientsAndStrategy.strategy)
        }
        
        return nil
    }
    
    private func encryptedMessagePayloadData(for recipients: Set<ZMUser>, externalData: Data?, context: NSManagedObjectContext) -> Data? {
        guard let selfClient = ZMUser.selfUser(in: context).selfClient(), selfClient.remoteIdentifier != nil
            else { return nil }
        
        let encryptionContext = selfClient.keysStore.encryptionContext
        var messageData : Data?
        
        encryptionContext.perform { (sessionsDirectory) in
            let message = otrMessage(selfClient, recipients: recipients, externalData: externalData, sessionDirectory: sessionsDirectory)
            
            messageData = message.data()
            
            // message too big?
            if let data = messageData, UInt(data.count) > ZMClientMessageByteSizeExternalThreshold && externalData == nil {
                // The payload is too big, we therefore rollback the session since we won't use the message we just encrypted.
                // This will prevent us advancing sender chain multiple time before sending a message, and reduce the risk of TooDistantFuture.
                sessionsDirectory.discardCache()
                messageData = encryptedMessageDataWithExternalDataBlob(recipients, context: context)
            }
        }
        
        // reset all failed sessions
        for recipient in recipients {
            recipient.clients.forEach({ $0.failedToEstablishSession = false })
        }
        
        return messageData
    }
    
    private var hasConfirmation: Bool {
        if case .confirmation? = content {
            return true
        }
        return false
    }
    
    /// Returns a message with recipients
    private func otrMessage(_ selfClient: UserClient,
                                recipients: Set<ZMUser>,
                                externalData: Data?,
                                sessionDirectory: EncryptionSessionsDirectory) -> ZMNewOtrMessage {
        
        let userEntries = recipientsWithEncryptedData(selfClient, recipients: recipients, sessionDirectory: sessionDirectory)
        let nativePush = !hasConfirmation // We do not want to send pushes for delivery receipts
        let message = ZMNewOtrMessage.message(withSender: selfClient, nativePush: nativePush, recipients: userEntries, blob: externalData)
        
        return message
    }

    /// Returns the recipients and the encrypted data for each recipient
    func recipientsWithEncryptedData(_ selfClient: UserClient,
                                     recipients: Set<ZMUser>,
                                     sessionDirectory: EncryptionSessionsDirectory) -> [ZMUserEntry]
    {
        let userEntries = recipients.compactMap { user -> ZMUserEntry? in
            guard !user.isAccountDeleted else { return nil }
            
            let clientsEntries = user.clients.compactMap { client -> ZMClientEntry? in
                
                guard client != selfClient, let clientRemoteIdentifier = client.sessionIdentifier else {
                    return nil
                }
                
                let hasSessionWithClient = sessionDirectory.hasSession(for: clientRemoteIdentifier)
                
                if !hasSessionWithClient {
                    // if the session is corrupted, we will send a special payload
                    if client.failedToEstablishSession {
                        let data = ZMFailedToCreateEncryptedMessagePayloadString.data(using: String.Encoding.utf8)!
                        return ZMClientEntry.entry(withClient: client, data: data)
                    }
                    else {
                        // if we do not have a session, we need to fetch a prekey and create a new session
                        return nil
                    }
                }
                guard let data = try? serializedData(),
                    let encryptedData = try? sessionDirectory.encryptCaching(data, for: clientRemoteIdentifier) else {
                        return nil
                }
                return ZMClientEntry.entry(withClient: client, data: encryptedData)
            }
            
            guard !clientsEntries.isEmpty else { return nil }
            return ZMUserEntry.entry(withUser: user, clientEntries: clientsEntries)
        }
        return userEntries
    }
    
    func recipientUsersForMessage(in conversation: ZMConversation, selfUser: ZMUser) -> (users: Set<ZMUser>, strategy: MissingClientsStrategy) {
        let (services, otherUsers) = conversation.localParticipants.categorizeServicesAndUser()
        
        func recipientForConfirmationMessage() -> Set<ZMUser>? {
            guard case .confirmation? = content, confirmation.hasFirstMessageID else { return nil }
            guard let message = ZMMessage.fetch(withNonce:UUID(uuidString:confirmation.firstMessageID), for:conversation, in:conversation.managedObjectContext!) else { return nil }
            guard let sender = message.sender else { return nil }
            return Set(arrayLiteral: sender)
        }
        
        func recipientForOtherUsers() -> Set<ZMUser>? {
            guard conversation.connectedUser != nil || (otherUsers.isEmpty == false) else { return nil }
            if let connectedUser = conversation.connectedUser { return Set(arrayLiteral:connectedUser) }
            return Set(otherUsers)
        }
        
        func recipientsForDeletedEphemeral() -> Set<ZMUser>? {
            guard case .deleted? = content, conversation.conversationType == .group else { return nil}
            let nonce = UUID(uuidString: deleted.messageID)
            guard let message = ZMMessage.fetch(withNonce:nonce, for:conversation, in:conversation.managedObjectContext!) else { return nil }
            guard message.destructionDate != nil else { return nil }
            guard let sender = message.sender else {
                zmLog.error("sender of deleted ephemeral message \(String(describing: deleted.messageID)) is already cleared \n ConvID: \(String(describing: conversation.remoteIdentifier)) ConvType: \(conversation.conversationType.rawValue)")
                return Set(arrayLiteral: selfUser)
            }
            
            // if self deletes their own message, we want to send delete msg
            // for everyone, so return nil.
            guard !sender.isSelfUser else { return nil }
            
            // otherwise we delete only for self and the sender, all other
            // recipients are unaffected.
            return Set(arrayLiteral: sender, selfUser)
        }
        
        func allAuthorizedRecipients() -> Set<ZMUser> {
            if let connectedUser = conversation.connectedUser { return Set(arrayLiteral: connectedUser, selfUser) }
            
            func mentionedServices() -> Set<ZMUser> {
                return services.filter { service in
                    textData?.mentions.contains { $0.userID == service.remoteIdentifier?.transportString() } ?? false
                }
            }
            
            let authorizedServices = ZMUser.servicesMustBeMentioned ? mentionedServices() : services
            
            return otherUsers.union(authorizedServices).union([selfUser])
        }
        
        var recipientUsers = Set<ZMUser>()
        
        if case .confirmation? = content {
            guard let recipients = recipientForConfirmationMessage() ?? recipientForOtherUsers() else {
                let confirmationInfo = ", original message: \(String(describing: confirmation.firstMessageID))"
                fatal("confirmation need a recipient\n ConvType: \(conversation.conversationType.rawValue) \(confirmationInfo)")
            }
            recipientUsers = recipients
        }
        else if let deletedEphemeral = recipientsForDeletedEphemeral() {
            recipientUsers = deletedEphemeral
        }
        else {
            recipientUsers = allAuthorizedRecipients()
        }
        
        let hasRestrictions: Bool = {
            if conversation.connectedUser != nil { return recipientUsers.count != 2 }
            return recipientUsers.count != conversation.localParticipants.count
        }()
        
        let strategy : MissingClientsStrategy = hasRestrictions ? .ignoreAllMissingClientsNotFromUsers(users: recipientUsers)
            : .doNotIgnoreAnyMissingClient
        
        return (recipientUsers, strategy)
    }
}

// MARK: - External
extension GenericMessage {
    private func encryptedMessageDataWithExternalDataBlob(_ recipients: Set<ZMUser>, context: NSManagedObjectContext) -> Data? {
        guard let encryptedDataWithKeys = GenericMessage.encryptedDataWithKeys(from: self) else { return nil }
        let externalGenericMessage = GenericMessage(content: External(withKeyWithChecksum: encryptedDataWithKeys.keys))
        return externalGenericMessage.encryptedMessagePayloadData(for: recipients, externalData: encryptedDataWithKeys.data, context: context)
    }
}
