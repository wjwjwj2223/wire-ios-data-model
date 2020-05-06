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

import XCTest
@testable import WireDataModel

class ClientMessageTests: BaseZMClientMessageTests {
    
    func testThatItCreatesClientMessagesFromUpdateEvent() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let nonce = UUID.create()
        let message = GenericMessage(content: Text(content: self.name, mentions: [], linkPreviews: [], replyingTo: nil), nonce: nonce)
        let contentData = try? message.serializedData()
        let data = contentData?.base64String()
        
        let payload = payloadForMessage(in: conversation, type: EventConversationAddClientMessage , data: data!)
        let event = ZMUpdateEvent.eventFromEventStreamPayload(payload, uuid: nil)
        XCTAssertNotNil(event)
        
        // when
        var sut: ZMClientMessage?
        self.performPretendingUiMocIsSyncMoc {
            sut = ZMClientMessage.createOrUpdate(from: event!, in: self.uiMOC, prefetchResult: nil)
        }
        
        // then
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut?.conversation, conversation)
        XCTAssertEqual(sut?.sender?.remoteIdentifier.transportString(), payload["from"] as? String)
        XCTAssertEqual(sut?.serverTimestamp?.transportString(), payload["time"] as? String)
        
        XCTAssertEqual(sut?.nonce, nonce)
        let messageData = try? sut?.underlyingMessage?.serializedData()
        XCTAssertEqual(messageData, contentData)
    }
    
    func testThatItCreatesOTRMessagesFromUpdateEvent() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let senderClientID = NSString.createAlphanumerical()
        let nonce = UUID.create()
        let message = GenericMessage(content: Text(content: self.name, mentions: [], linkPreviews: [], replyingTo: nil), nonce: nonce)
        let contentData = try? message.serializedData()
        
        let data: NSDictionary = [
            "sender": senderClientID,
            "text": contentData?.base64String()
        ]
        let payload = payloadForMessage(in: conversation, type: EventConversationAddOTRMessage , data: data)
        
        let event = ZMUpdateEvent.eventFromEventStreamPayload(payload, uuid: nil)
        XCTAssertNotNil(event)
        
        // when
        var sut: ZMClientMessage?
        self.performPretendingUiMocIsSyncMoc {
            sut = ZMClientMessage.createOrUpdate(from: event!, in: self.uiMOC, prefetchResult: nil)
        }
        
        // then
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut?.conversation, conversation)
        XCTAssertEqual(sut?.sender?.remoteIdentifier.transportString(), payload["from"] as? String)
        XCTAssertEqual(sut?.serverTimestamp?.transportString(), payload["time"] as? String)
        XCTAssertEqual(sut?.senderClientID, senderClientID)
        
        XCTAssertEqual(sut?.nonce, nonce)
        let messageData = try? sut?.underlyingMessage?.serializedData()
        XCTAssertEqual(messageData, contentData)
    }
    
    func testThatItIgnores_AnyAdditionalFieldsInTheLinkPreviewUpdate() {
        // given
        let initialText = "initial text"
        
        let nonce = UUID.create()
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let selfClient = self.createSelfClient()
        
        let existingMessage = ZMClientMessage(nonce: nonce, managedObjectContext: self.uiMOC)
        let message = GenericMessage(content: Text(content: initialText, mentions: [], linkPreviews: [], replyingTo: nil), nonce: nonce)

        do {
            existingMessage.add(try message.serializedData())
        } catch {}
        existingMessage.visibleInConversation = conversation
        existingMessage.sender = self.selfUser
        existingMessage.senderClientID = selfClient.remoteIdentifier
        
        // We add a quote to the link preview update
        
        let linkPreview = LinkPreview.with {
            $0.url = "http://www.sunet.se"
            $0.permanentURL = "http://www.sunet.se"
            $0.urlOffset = 0
            $0.title = "Test"
        }
        let messageText = Text.with {
            $0.content = initialText
            $0.mentions = []
            $0.linkPreview = [linkPreview]
            $0.quote = Quote.with({
                $0.quotedMessageID = existingMessage.nonce?.transportString() ?? ""
                $0.quotedMessageSha256 = existingMessage.hashOfContent!
            })
        }
        let modifiedMessage = GenericMessage(content: messageText, nonce: nonce)
        
        let modifiedMessageData = try? modifiedMessage.serializedData().base64String()
        let data: NSDictionary = [
            "sender": selfClient.remoteIdentifier,
            "recipient": selfClient.remoteIdentifier,
            "text": modifiedMessageData
        ]
        let payload = payloadForMessage(in: conversation, type: EventConversationAddOTRMessage, data: data, time: Date(), from: self.selfUser)

        
        let event = ZMUpdateEvent.eventFromEventStreamPayload(payload, uuid: nil)
        XCTAssertNotNil(event)
        
        // when
        var sut: ZMClientMessage?
        self.performPretendingUiMocIsSyncMoc {
            sut = ZMClientMessage.createOrUpdate(from: event!, in: self.uiMOC, prefetchResult: nil)
        }
        
        // then
        XCTAssertNotNil(sut)
        XCTAssertNotNil(existingMessage.linkPreview)
        XCTAssertFalse(existingMessage.underlyingMessage!.textData!.hasQuote)
        XCTAssertEqual(existingMessage.textMessageData?.messageText, initialText)
    }
    
    func testThatItIgnoresBlacklistedLinkPreview() {
        // given
        let initialText = "initial text"
        
        let nonce = UUID.create()
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let selfClient = self.createSelfClient()
        
       let existingMessage = ZMClientMessage(nonce: nonce, managedObjectContext: self.uiMOC)
        let message = GenericMessage(content: Text(content: initialText, mentions: [], linkPreviews: [], replyingTo: nil), nonce: nonce)
        do {
            existingMessage.add(try message.serializedData())
        } catch {}
        existingMessage.visibleInConversation = conversation;
        existingMessage.sender = self.selfUser;
        existingMessage.senderClientID = selfClient.remoteIdentifier;
        
        // We add a quote to the link preview update
        let linkPreview = LinkPreview.with {
            $0.url = "http://www.youtube.com/watch"
            $0.permanentURL = "http://www.youtube.com/watch"
            $0.urlOffset = 0
            $0.title = "YouTube"
        }
        let messageText = Text.with {
            $0.content = initialText
            $0.mentions = []
            $0.linkPreview = [linkPreview]
            $0.quote = Quote.with({
                $0.quotedMessageID = existingMessage.nonce?.transportString() ?? ""
                $0.quotedMessageSha256 = existingMessage.hashOfContent!
            })
        }
        let modifiedMessage = GenericMessage(content: messageText, nonce: nonce)
        
        let modifiedMessageData = try? modifiedMessage.serializedData().base64String()
        let data: NSDictionary = [
            "sender": selfClient.remoteIdentifier,
            "recipient": selfClient.remoteIdentifier,
            "text": modifiedMessageData
        ]
        let payload = payloadForMessage(in: conversation, type: EventConversationAddOTRMessage, data: data, time: Date(), from: self.selfUser)
        
        let event = ZMUpdateEvent.eventFromEventStreamPayload(payload, uuid: nil)
        XCTAssertNotNil(event);
        
        // when
        var sut: ZMClientMessage?
        self.performPretendingUiMocIsSyncMoc {
            sut = ZMClientMessage.createOrUpdate(from: event!, in: self.uiMOC, prefetchResult: nil)
        }
        
        // then
        XCTAssertNotNil(sut)
        XCTAssertNotNil(existingMessage.firstZMLinkPreview)
        XCTAssertNil(existingMessage.linkPreview) // do not return a link preview even if it's included in the protobuf
        XCTAssertFalse(existingMessage.underlyingMessage!.textData!.hasQuote)
        XCTAssertEqual(existingMessage.textMessageData?.messageText, initialText)
    }
    
    func testThatItCanUpdateAnExistingLinkPreviewInTheDataSetWithoutCreatingMultipleOnes() {
        self.syncMOC.performGroupedAndWait {_ in
            // given
            let nonce = UUID.create()
            let message = ZMClientMessage(nonce: nonce, managedObjectContext: self.syncMOC)
            let otrKey = Data.randomEncryptionKey()
            let sha256 = Data.zmRandomSHA256Key()
            
            // when
            let remoteData = WireProtos.Asset.RemoteData.with {
                $0.otrKey = otrKey
                $0.sha256 = sha256
            }
            let asset = WireProtos.Asset.with {
                $0.uploaded = remoteData
            }
            let linkPreview = LinkPreview.with {
                $0.url = self.name
                $0.permanentURL = "www.example.de"
                $0.urlOffset = 0
                $0.title = "Title"
                $0.summary = "Summary"
                $0.image = asset
            }
            let text = Text.with {
                $0.content = self.name
                $0.linkPreview = [linkPreview]
            }
            let genericMessage = GenericMessage(content: text, nonce: nonce)
            do {
                message.add(try genericMessage.serializedData())
            } catch {}
            
            // then
            XCTAssertEqual(message.dataSet.count, 1)
            switch message.underlyingMessage?.content {
            case .text(let data)?:
                XCTAssertNotNil(data)
            default:
                XCTFail()
            }
            XCTAssertEqual(message.underlyingMessage!.text.linkPreview.count, 1)
            
            // when
            var second = GenericMessage()
            try? second.merge(serializedData: message.underlyingMessage!.serializedData())
            var textSecond = second.text
            var linkPreviewSecond = second.text.linkPreview.first
            var assetSecond = linkPreviewSecond?.image
            var remoteSecond = linkPreviewSecond?.image.uploaded
            remoteSecond?.assetID = "Asset ID"
            remoteSecond?.assetToken = "Asset Token"
            
            assetSecond?.uploaded = remoteSecond!
            linkPreviewSecond?.image = assetSecond!
            textSecond.linkPreview = [linkPreviewSecond!]
            second.text = textSecond
            
            do {
                message.add(try second.serializedData())
            } catch {}
            
            // then
            XCTAssertEqual(message.dataSet.count, 1)
            switch message.underlyingMessage?.content {
            case .text(let data)?:
                XCTAssertNotNil(data)
            default:
                XCTFail()
            }
            XCTAssertEqual(message.underlyingMessage!.text.linkPreview.count, 1)
            let remote = message.underlyingMessage?.text.linkPreview.first?.image.uploaded
            XCTAssertEqual(remote?.assetID, "Asset ID")
            XCTAssertEqual(remote?.assetToken, "Asset Token")
        }
    }

}
