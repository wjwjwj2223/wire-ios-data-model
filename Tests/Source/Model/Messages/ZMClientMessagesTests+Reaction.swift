//
//  ZMClientMessagesTests+Reaction.swift
//  ZMCDataModel
//
//  Created by Florian Morel on 9/6/16.
//  Copyright © 2016 Wire Swiss GmbH. All rights reserved.
//

import ZMTesting

class ZMClientMessageTests_Reaction: BaseZMClientMessageTests {
    
    
}

extension ZMClientMessageTests_Reaction {
    
    func testThatItAppendsAReactionWhenReceivingUpdateEventWithValidReaction() {
        
        let conversation = ZMConversation.insertNewObject(in:uiMOC)
        conversation.remoteIdentifier = .create()
        conversation.conversationType = .oneOnOne
        
        let sender = ZMUser.insertNewObject(in:uiMOC)
        sender.remoteIdentifier = .create()
        
        let message = conversation.appendMessage(withText: "JCVD, full split please") as! ZMMessage
        message.sender = sender
        
        uiMOC.saveOrRollback()
        
        let genericMessage = ZMGenericMessage(emojiString: "❤️", messageID: message.nonce.transportString(), nonce: UUID.create().transportString())!
        let event = createUpdateEvent(UUID(), conversationID: conversation.remoteIdentifier, genericMessage: genericMessage, senderID: sender.remoteIdentifier!)
        
        // when
        performPretendingUiMocIsSyncMoc {
            ZMClientMessage.messageUpdateResult(from: event, in: self.uiMOC, prefetchResult: nil)
        }
        XCTAssertTrue(uiMOC.saveOrRollback())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        
        XCTAssertEqual(message.reactions.count, 1)
        XCTAssertEqual(message.usersReaction.count, 1)
    }
    
    func testThatItDoesNOTAppendsAReactionWhenReceivingUpdateEventWithValidReaction() {
        
        let conversation = ZMConversation.insertNewObject(in:uiMOC)
        conversation.remoteIdentifier = .create()
        conversation.conversationType = .oneOnOne
        
        let sender = ZMUser.insertNewObject(in:uiMOC)
        sender.remoteIdentifier = .create()
        
        let message = conversation.appendMessage(withText: "JCVD, full split please") as! ZMMessage
        message.sender = sender
        
        uiMOC.saveOrRollback()
        
        let genericMessage = ZMGenericMessage(emojiString: "TROP BIEN", messageID: message.nonce.transportString(), nonce: UUID.create().transportString())!
        let event = createUpdateEvent(UUID(), conversationID: conversation.remoteIdentifier, genericMessage: genericMessage, senderID: sender.remoteIdentifier!)
        
        // when
        performPretendingUiMocIsSyncMoc {
            ZMClientMessage.messageUpdateResult(from: event, in: self.uiMOC, prefetchResult: nil)
        }
        XCTAssertTrue(uiMOC.saveOrRollback())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        
        XCTAssertEqual(message.reactions.count, 0)
        XCTAssertEqual(message.usersReaction.count, 0)
    }
    
    func testThatItRemovesAReactionWhenReceivingUpdateEventWithValidReaction() {
        
        let conversation = ZMConversation.insertNewObject(in:uiMOC)
        conversation.remoteIdentifier = .create()
        conversation.conversationType = .oneOnOne
        
        let sender = ZMUser.insertNewObject(in:uiMOC)
        sender.remoteIdentifier = .create()
        
        let message = conversation.appendMessage(withText: "JCVD, full split please") as! ZMMessage
        message.sender = sender
        message.addReaction("❤️", forUser: sender)
        
        uiMOC.saveOrRollback()
        
        let genericMessage = ZMGenericMessage(emojiString: "", messageID: message.nonce.transportString(), nonce: UUID.create().transportString()!)!
        let event = createUpdateEvent(UUID(), conversationID: conversation.remoteIdentifier, genericMessage: genericMessage, senderID: sender.remoteIdentifier!)
        
        // when
        performPretendingUiMocIsSyncMoc {
            ZMClientMessage.messageUpdateResult(from: event, in: self.uiMOC, prefetchResult: nil)
        }
        XCTAssertTrue(uiMOC.saveOrRollback())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        

        XCTAssertEqual(message.usersReaction.count, 0)
    }

}
