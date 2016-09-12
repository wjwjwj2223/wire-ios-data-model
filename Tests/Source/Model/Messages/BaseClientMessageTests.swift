//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
@testable import ZMCDataModel

class BaseZMClientMessageTests : BaseZMMessageTests {
    
    var syncSelfUser: ZMUser!
    var user1: ZMUser!
    var user2: ZMUser!
    var user3: ZMUser!
    
    var selfClient1: UserClient!
    var selfClient2: UserClient!
    var user1Client1: UserClient!
    var user1Client2: UserClient!
    var user2Client1: UserClient!
    var user2Client2: UserClient!
    var user3Client1: UserClient!
    
    var conversation: ZMConversation!
    
    var expectedRecipients: [String: [String]]!
    
    override func setUp() {
        super.setUp()
        setUpCaches()

        syncSelfUser = ZMUser.selfUser(in: self.syncMOC);
        
        selfClient1 = createSelfClient()
        syncMOC.setPersistentStoreMetadata(selfClient1.remoteIdentifier, forKey: "PersistedClientId")
        
        selfClient2 = createClient(for: syncSelfUser, createSessionWithSelfUser: true)
        
        user1 = ZMUser.insertNewObject(in:self.syncMOC);
        user1Client1 = createClient(for: user1, createSessionWithSelfUser: true)
        user1Client2 = createClient(for: user1, createSessionWithSelfUser: true)
        
        user2 = ZMUser.insertNewObject(in:self.syncMOC);
        user2Client1 = createClient(for: user2, createSessionWithSelfUser: true)
        user2Client2 = createClient(for: user2, createSessionWithSelfUser: false)
        
        user3 = ZMUser.insertNewObject(in:self.syncMOC);
        user3Client1 = createClient(for: user3, createSessionWithSelfUser: false)
        
        conversation = ZMConversation.insertGroupConversation(into: self.syncMOC, withParticipants: [user1, user2, user3])
        
        expectedRecipients = [
            syncSelfUser.remoteIdentifier!.transportString()!: [
                selfClient2.remoteIdentifier
            ],
            user1.remoteIdentifier!.transportString()!: [
                user1Client1.remoteIdentifier,
                user1Client2.remoteIdentifier
            ],
            user2.remoteIdentifier!.transportString()!: [
                user2Client1.remoteIdentifier
            ]
        ]
        
    }
    
    override func tearDown() {
        syncMOC.setPersistentStoreMetadata(nil, forKey: "PersistedClientId")
        wipeCaches()
        super.tearDown()
    }
    
    func assertRecipients(_ recipients: [ZMUserEntry], file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(recipients.count, expectedRecipients.count, file: file, line: line)
        
        for recipientEntry in recipients {
            var uuid : NSUUID!
            recipientEntry.user.uuid.withUnsafeBytes({ bytes in
                uuid = NSUUID(uuidBytes: bytes)
            })
            guard let expectedClientsIds : [String] = self.expectedRecipients[uuid.transportString()]?.sorted() else {
                XCTFail("Unexpected otr client in recipients", file: file, line: line)
                return
            }
            let clientIds = (recipientEntry.clients as! [ZMClientEntry]).map { String(format: "%llx", $0.client.client) }.sorted()
            XCTAssertEqual(clientIds, expectedClientsIds, file: file, line: line)
            let hasTexts = (recipientEntry.clients as! [ZMClientEntry]).map { $0.hasText() }
            XCTAssertFalse(hasTexts.contains(false), file: file, line: line)
            
        }
    }
    
    func createUpdateEvent(_ nonce: UUID, conversationID: UUID, genericMessage: ZMGenericMessage, senderID: UUID = .create(), eventSource: ZMUpdateEventSource = .download) -> ZMUpdateEvent {
        let payload : [String : Any] = [
            "id": UUID.create().transportString(),
            "conversation": conversationID.transportString(),
            "from": senderID.transportString(),
            "time": Date().transportString(),
            "data": [
                "text": genericMessage.data().base64String()
            ],
            "type": "conversation.otr-message-add"
        ]
        switch eventSource {
        case .download:
            return ZMUpdateEvent(fromEventStreamPayload: payload as ZMTransportData, uuid: nonce)
        default:
            let streamPayload = ["payload" : [payload],
                                 "id" : UUID.create().transportString()] as [String : Any]
            let event = ZMUpdateEvent.eventsArray(from: streamPayload as ZMTransportData,
                                                                   source: eventSource)!.first!
            XCTAssertNotNil(event)
            return event
        }
    }

}
