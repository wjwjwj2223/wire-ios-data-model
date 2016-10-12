//
//  ZMClientMessageTests+Ephemeral.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 29/09/16.
//  Copyright © 2016 Wire Swiss GmbH. All rights reserved.
//

import Foundation
import Cryptobox
import ZMCLinkPreview

@testable import ZMCDataModel

class ZMClientMessageTests_Ephemeral : BaseZMClientMessageTests {
    // TODO Sabine: in the message transcoder make sure that there are no race conditions
    // e.g. second part completes from server, first part already deleted
    override func tearDown() {
        syncMOC.performGroupedBlockAndWait {
            self.syncMOC.zm_teardownMessageObfuscationTimer()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        uiMOC.performGroupedBlockAndWait {
            self.uiMOC.zm_teardownMessageDeletionTimer()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        super.tearDown()
    }
    
    var obfuscationTimer : ZMMessageDestructionTimer {
        return syncMOC.zm_messageObfuscationTimer
    }
    
    var deletionTimer : ZMMessageDestructionTimer {
        return uiMOC.zm_messageDeletionTimer
    }
}

// MARK: Sending
extension ZMClientMessageTests_Ephemeral {
    
    func testThatItCreateAEphemeralMessageWhenAutoDeleteTimeoutIs_SetToBiggerThanZero_OnConversation(){
        // given
        let timeout : TimeInterval = 10
        conversation.messageDestructionTimeout = timeout
        
        // when
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        
        // then
        XCTAssertTrue(message.isEphemeral)
        XCTAssertTrue(message.genericMessage!.ephemeral.hasText())
        XCTAssertEqual(message.deletionTimeout, timeout)
    }
    
    func testThatIt_DoesNot_CreateAnEphemeralMessageWhenAutoDeleteTimeoutIs_SetToZero_OnConversation(){
        // given
        conversation.messageDestructionTimeout = 0
        
        // when
        let message = conversation.appendMessage(withText: "foo") as! ZMMessage
        
        // then
        XCTAssertFalse(message.isEphemeral)
    }
    
    func testThatWhenCreatingAMultipartMessageItUsesTheTimeoutSetInTheFirstCreatedPartForAllParts(){
        // given
        let timeout : TimeInterval = 10
        conversation.messageDestructionTimeout = timeout

        // when
        let message = conversation.appendMessage(withImageData: verySmallJPEGData()) as! ZMAssetClientMessage
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let previewGenericMessage = message.genericMessage(for: .placeholder)
        XCTAssertTrue(previewGenericMessage!.hasEphemeral())
        XCTAssertEqual(previewGenericMessage!.ephemeral.expireAfterMillis, 10*1000)
        
        let mediumGenericMessage = message.genericMessage(for: .fullAsset)
        XCTAssertTrue(mediumGenericMessage!.hasEphemeral())
        XCTAssertEqual(mediumGenericMessage!.ephemeral.expireAfterMillis, 10*1000)
    }
    
    func checkItCreatesAnEphemeralMessage(messageCreationBlock: ((ZMConversation) -> ZMMessage)) {
        // given
        let timeout : TimeInterval = 10
        conversation.messageDestructionTimeout = timeout
        
        // when
        let message = conversation.appendMessage(withText: "foo") as! ZMMessage
        
        // then
        XCTAssertTrue(message.isEphemeral)
        XCTAssertEqual(message.deletionTimeout, timeout)
    }
    
    func testItCreatesAnEphemeralMessageForKnock(){
        checkItCreatesAnEphemeralMessage { (conv) -> ZMMessage in
            let message = conv.appendKnock() as! ZMClientMessage
            XCTAssertTrue(message.genericMessage!.ephemeral.hasKnock())
            return message
        }
    }
    
    func testItCreatesAnEphemeralMessageForLocation(){
        checkItCreatesAnEphemeralMessage { (conv) -> ZMMessage in
            let location = LocationData(latitude: 1.0, longitude: 1.0, name: "foo", zoomLevel: 1)
            let message = conv.appendOTRMessage(with: location, nonce: UUID.create())
            XCTAssertTrue(message.genericMessage!.ephemeral.hasLocation())
            return message
        }
    }

    func testItCreatesAnEphemeralMessageForImages(){
        checkItCreatesAnEphemeralMessage { (conv) -> ZMMessage in
            let message = conv.appendMessage(withImageData: verySmallJPEGData()) as! ZMAssetClientMessage
            XCTAssertTrue(message.genericAssetMessage!.ephemeral.hasImage())
            return message
        }
    }
    
    func testThatItStartsATimerWhenTheMessageIsMarkedAsSent() {
        self.syncMOC.performGroupedBlockAndWait {
            // given
            let timeout : TimeInterval = 10
            self.syncConversation.messageDestructionTimeout = timeout
            let message = self.syncConversation.appendMessage(withText: "foo") as! ZMClientMessage
            XCTAssertEqual(self.obfuscationTimer.runningTimersCount, 0)

            // when
            message.markAsSent()
            
            // then
            XCTAssertTrue(message.isEphemeral)
            XCTAssertEqual(message.deletionTimeout, timeout)
            XCTAssertNotNil(message.destructionDate)
            XCTAssertEqual(self.obfuscationTimer.runningTimersCount, 1)
        }
    }
    
    func testThatItDoesNotStartATimerWhenTheMessageHasUnsentLinkPreviewAndIsMarkedAsSent() {
        self.syncMOC.performGroupedBlockAndWait {
            // given
            let timeout : TimeInterval = 10
            self.syncConversation.messageDestructionTimeout = timeout
            
            let article = Article(
                originalURLString: "www.example.com/article/original",
                permamentURLString: "http://www.example.com/article/1",
                offset: 12
            )
            article.title = "title"
            article.summary = "summary"
            let linkPreview = article.protocolBuffer.update(withOtrKey: Data(), sha256: Data())
            let genericMessage = ZMGenericMessage.message(text: "foo", linkPreview: linkPreview, nonce: UUID.create().transportString(), expiresAfter: NSNumber(value: timeout))
            let message = self.syncConversation.appendClientMessage(with: genericMessage.data())
            message.linkPreviewState = .processed
            XCTAssertEqual(message.linkPreviewState, .processed)
            XCTAssertEqual(self.obfuscationTimer.runningTimersCount, 0)
            
            // when
            message.markAsSent()
            
            // then
            XCTAssertTrue(message.isEphemeral)
            XCTAssertEqual(message.deletionTimeout, timeout)
            XCTAssertNil(message.destructionDate)
            XCTAssertEqual(self.obfuscationTimer.runningTimersCount, 0)
            
            // and when
            message.linkPreviewState = .done
            message.markAsSent()
            
            // then 
            XCTAssertNotNil(message.destructionDate)
            XCTAssertEqual(self.obfuscationTimer.runningTimersCount, 1)
        }
    }
    
    // TODO test for Asset, External, Image
    func testThatItClearsTheMessageContentWhenTheTimerFiresAndSetsIsObfuscatedToTrue(){
        var message : ZMClientMessage!
        
        self.syncMOC.performGroupedBlockAndWait {
            // given
            let timeout : TimeInterval = 0.1
            self.syncConversation.messageDestructionTimeout = timeout
            message = self.syncConversation.appendMessage(withText: "foo") as! ZMClientMessage
            
            // when
            message.markAsSent()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        spinMainQueue(withTimeout: 0.5)
        
        self.syncMOC.performGroupedBlock {
            // then
            XCTAssertTrue(message.isEphemeral)
            XCTAssertNotNil(message.destructionDate)
            XCTAssertTrue(message.isObfuscated)
            XCTAssertNotNil(message.sender)
            XCTAssertNotEqual(message.hiddenInConversation, self.syncConversation)
            XCTAssertEqual(message.visibleInConversation, self.syncConversation)
            XCTAssertNotNil(message.genericMessage)
            XCTAssertNotEqual(message.genericMessage?.textData?.content, "foo")
            XCTAssertEqual(self.obfuscationTimer.runningTimersCount, 0)
        }
    }
    
    
    func testThatItDoesNotStartTheTimerWhenTheMessageExpires(){
        self.syncMOC.performGroupedBlockAndWait {
            // given
            let timeout : TimeInterval = 0.1
            self.syncConversation.messageDestructionTimeout = timeout
            let message = self.syncConversation.appendMessage(withText: "foo") as! ZMClientMessage
            
            // when
            message.expire()
            self.spinMainQueue(withTimeout: 0.5)

            // then
            XCTAssertEqual(self.obfuscationTimer.runningTimersCount, 0)
        }
    }
    
    func testThatItDeletesTheEphemeralMessageWhenItReceivesADeleteForItFromOtherUser(){
        var message : ZMClientMessage!

        self.syncMOC.performGroupedBlockAndWait {
            // given
            let timeout : TimeInterval = 0.1
            self.syncConversation.messageDestructionTimeout = timeout
            message = self.syncConversation.appendMessage(withText: "foo") as! ZMClientMessage
            message.markAsSent()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        spinMainQueue(withTimeout: 0.5)
        
        self.syncMOC.performGroupedBlockAndWait {
            XCTAssertTrue(message.isObfuscated)
            XCTAssertNotNil(message.destructionDate)

            // when
            let delete = ZMGenericMessage(deleteMessage: message.nonce.transportString(), nonce: UUID.create().transportString())
            let event = self.createUpdateEvent(UUID.create(), conversationID: self.syncConversation.remoteIdentifier!, genericMessage: delete, senderID: self.syncUser1.remoteIdentifier!, eventSource: .download)
            _ = ZMOTRMessage.messageUpdateResult(from: event, in: self.syncMOC, prefetchResult: nil)
            
            // then
            XCTAssertNil(message.sender)
            XCTAssertNil(message.genericMessage)
        }
    }

    func testThatTheRequestPayloadForAnEphemeralMessageOnlyContainsTheOtherUsersClients(){
       // TODO Sabine: Integration Test in Sync Engine, implement after merging mike's changes
    }


}


// MARK: Receiving
extension ZMClientMessageTests_Ephemeral {

    func testThatItStartsATimerIfTheMessageIsAMessageOfTheOtherUser(){
        // given
        conversation.messageDestructionTimeout = 10
        conversation.lastReadServerTimeStamp = Date()
        let sender = ZMUser.insertNewObject(in: uiMOC)
        sender.remoteIdentifier = UUID.create()
        
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        message.sender = sender
        
        // when
        XCTAssertTrue(message.startSelfDestructionIfNeeded())
        
        // then
        XCTAssertEqual(self.deletionTimer.runningTimersCount, 1)
        XCTAssertTrue(self.deletionTimer.isTimerRunning(for: message))
    }
    
    
    func testThatItDoesNotStartATimerForAMessageOfTheSelfuser(){
        // given
        let timeout : TimeInterval = 0.1
        conversation.messageDestructionTimeout = timeout
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        
        // when
        XCTAssertFalse(message.startDestructionIfNeeded())
        
        // then
        XCTAssertEqual(self.deletionTimer.runningTimersCount, 0)
    }
    
    func testThatItCreatesADeleteForAllMessageWhenTheTimerFires(){
        // given
        let timeout : TimeInterval = 0.1
        conversation.messageDestructionTimeout = timeout
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        message.sender = ZMUser.insertNewObject(in: uiMOC)
        message.sender?.remoteIdentifier = UUID.create()

        // when
        XCTAssertTrue(message.startDestructionIfNeeded())
        XCTAssertEqual(self.deletionTimer.runningTimersCount, 1)
        
        spinMainQueue(withTimeout: 0.5)
        
        // then
        guard let deleteMessage = conversation.hiddenMessages.firstObject as? ZMClientMessage
        else { return XCTFail()}
        print(deleteMessage)
        print(deleteMessage.genericMessage)

        guard let genericMessage = deleteMessage.genericMessage, genericMessage.hasDeleted()
        else {return XCTFail()}

        XCTAssertTrue(message.isEphemeral)
        XCTAssertNotEqual(deleteMessage, message)
        XCTAssertNil(message.sender)
        XCTAssertNil(message.genericMessage)
        XCTAssertNotNil(message.destructionDate)
    }
    
}


extension ZMClientMessageTests_Ephemeral {

    
    func hasDeleteMessage(for message: ZMMessage) -> Bool {
        guard let deleteMessage = (conversation.hiddenMessages.firstObject as? ZMClientMessage)?.genericMessage,
            deleteMessage.hasDeleted(), deleteMessage.deleted.messageId == message.nonce.transportString()
            else { return false }
        return true
    }
    
    func insertEphemeralMessage() -> ZMMessage {
        let timeout : TimeInterval = 1.0
        conversation.messageDestructionTimeout = timeout
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        message.sender = ZMUser.insertNewObject(in: uiMOC)
        message.sender?.remoteIdentifier = UUID.create()
        uiMOC.saveOrRollback()
        return message
    }
    

    func testThatItRestartsTheTimerWhenTimerHadStartedAndDestructionDateIsInFuture(){
        // given
        let message = insertEphemeralMessage()
        
        // when
        // start timer
        XCTAssertTrue(message.startDestructionIfNeeded())
        XCTAssertNotNil(message.destructionDate)
        
        // stop app (timer stops)
        deletionTimer.stop(for: message)
        XCTAssertNotNil(message.sender)
        
        // restart app
        ZMMessage.deleteOldEphemeralMessages(self.uiMOC)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(conversation.hiddenMessages.count, 0)
        XCTAssertTrue(deletionTimer.isTimerRunning(for: message))
    }

    func testThatItDeletesMessagesFromOtherUserWhenTimerHadStartedAndDestructionDateIsInPast(){
        // given
        let message = insertEphemeralMessage()
        
        // when
        // start timer
        XCTAssertTrue(message.startDestructionIfNeeded())
        XCTAssertNotNil(message.destructionDate)
        
        // stop app (timer stops)
        deletionTimer.stop(for: message)
        XCTAssertNotNil(message.sender)
        // wait for destruction date to be passed
        spinMainQueue(withTimeout: 1.0)
        XCTAssertNotNil(message.sender)
        
        // restart app
        ZMMessage.deleteOldEphemeralMessages(self.uiMOC)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(conversation.hiddenMessages.count, 0)
        XCTAssertTrue(deletionTimer.isTimerRunning(for: message))
    }
    
    func testThatItDoesNotDeleteMessagesFromOtherUserWhenTimerHad_Not_Started(){
        // given
        let message = insertEphemeralMessage()
        
        // when
        ZMMessage.deleteOldEphemeralMessages(self.uiMOC)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(hasDeleteMessage(for: message))
        XCTAssertNil(message.sender)
        XCTAssertEqual(message.hiddenInConversation, conversation)
    }
    
    func obfuscatedMessagesByTheSelfUser(timerHadStarted: Bool) -> Bool {
        var isObfuscated = false
        self.syncMOC.performGroupedBlockAndWait {
            // given
            let timeout : TimeInterval = 10
            self.syncConversation.messageDestructionTimeout = timeout
            let message = self.syncConversation.appendMessage(withText: "foo") as! ZMClientMessage
            
            if timerHadStarted {
                message.markAsSent()
                XCTAssertNotNil(message.destructionDate)
            }
            
            // when
            ZMMessage.deleteOldEphemeralMessages(self.syncMOC)
            isObfuscated = message.isObfuscated
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        return isObfuscated;
    }
    
    func testThatItObfuscatesTheMessageWhenTheTimerWasStarted(){
        XCTAssertTrue(obfuscatedMessagesByTheSelfUser(timerHadStarted: true))
    }
    
    func testThatItDoesNotObfuscateTheMessageWhenTheTimerWas_Not_Started(){
        XCTAssertFalse(obfuscatedMessagesByTheSelfUser(timerHadStarted: false))
    }
    
}


