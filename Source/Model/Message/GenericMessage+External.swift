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

private let zmLog = ZMSLog(tag: "GenericMessage")

extension GenericMessage {
    /// @abstract Helper to generate the payload for a generic message of type @c external
    /// @discussion In case the payload of a regular (text) message is to large,
    /// we need to symmetrically encrypt the original generic message using a generated
    /// symmetric key. A generic message of type @c external which contains the key
    /// used for the symmetric encryption and the sha-256 checksum og the encoded data needs to be created.
    /// When sending the @c external message the encrypted original message should be attached to the payload
    /// in the @c blob field of the protocol buffer.
    /// @param message The message that should be encrypted to sent it as attached payload in a @c external message
    /// @return The encrypted original message, the encryption key and checksum warpped in a @c ZMExternalEncryptedDataWithKeys
    static func encryptedDataWithKeys(from message: GenericMessage) -> ZMExternalEncryptedDataWithKeys? {
        guard
            let aesKey = NSData.randomEncryptionKey(),
            let messageData = try? message.serializedData()
            else {
                return nil
        }
        let encryptedData = messageData.zmEncryptPrefixingPlainTextIV(key: aesKey)
        let keys = ZMEncryptionKeyWithChecksum.key(withAES: aesKey, digest: encryptedData.zmSHA256Digest())
        return ZMExternalEncryptedDataWithKeys(data: encryptedData, keys: keys)
    }
    
    /// @abstract Creates a genericMessage from a @c ZMUpdateEvent and @c External
    /// @discussion The symetrically encrypted data (representing the original @c GenericMessage)
    /// contained in the update event will be decrypted using the encryption keys in the @c External
    /// @param updateEvent The decrypted @c ZMUpdateEvent containing the external data
    /// @param external @c The @c External containing the otrKey used for the symmetric encryption and the sha256 checksum
    /// @return The decrypted original @c GenericMessage that was contained in the update event
    init?(from updateEvent: ZMUpdateEvent, withExternal external: External) {
        guard let externalDataString = updateEvent.payload.optionalString(forKey: "external") else { return nil }
        let externalData = Data(base64Encoded: externalDataString)
        let externalSha256 = externalData?.zmSHA256Digest()
        
        guard externalSha256 == external.sha256 else {
            zmLog.error("Invalid hash for external data: \(externalSha256 ?? Data()) != \(external.sha256), updateEvent: \(updateEvent)")
            return nil
        }
        
        let decryptedData = externalData?.zmDecryptPrefixedPlainTextIV(key: external.otrKey)
        guard let message = GenericMessage(withBase64String: decryptedData?.base64String()) else {
            return nil
        }
        self = message
    }
}
