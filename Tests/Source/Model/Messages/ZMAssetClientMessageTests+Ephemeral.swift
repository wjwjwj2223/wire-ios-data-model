//
//  ZMAssetClientMessageTests+Ephemeral.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 30/09/16.
//  Copyright © 2016 Wire Swiss GmbH. All rights reserved.
//

import Foundation
@testable import ZMCDataModel

class ZMAssetClientMessageTests_Ephemeral : BaseZMAssetClientMessageTests {
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
extension ZMAssetClientMessageTests_Ephemeral {

    func testThatItInsertsAnEphemeralMessageForAssets(){
        // given
        conversation.messageDestructionTimeout = 10
        let fileMetadata = addFile().0
        
        // when
        let message = conversation.appendMessage(with: fileMetadata) as! ZMAssetClientMessage
        
        // then
        XCTAssertTrue(message.genericAssetMessage!.hasEphemeral())
        XCTAssertTrue(message.genericAssetMessage!.ephemeral.hasAsset())
        XCTAssertEqual(message.genericAssetMessage!.ephemeral.expireAfterMillis, Int64(10*1000))
    }
    
    func testThatItStartsTheTimerForMultipartMessagesWhenTheAssetIsUploaded(){
        self.syncMOC.performGroupedBlockAndWait {
            // given
            self.syncConversation.messageDestructionTimeout = 10
            let fileMetadata = self.addFile().0
            let message = self.syncConversation.appendMessage(with: fileMetadata) as! ZMAssetClientMessage
            message.uploadState = .uploadingFullAsset
            
            // when
            message.update(withPostPayload: [:], updatedKeys: Set(arrayLiteral: ZMAssetClientMessageUploadedStateKey))
            
            // then
            XCTAssertEqual(message.uploadState, ZMAssetUploadState.uploadingFullAsset)
            XCTAssertEqual(self.obfuscationTimer.runningTimersCount, 1)
            XCTAssertTrue(self.obfuscationTimer.isTimerRunning(for: message))
        }
    }
    
    func testThatItDoesNotStartTheTimerForMultipartMessagesWhenTheAssetWasNotUploaded(){
        self.syncMOC.performGroupedBlockAndWait {
            // given
            self.syncConversation.messageDestructionTimeout = 10
            let fileMetadata = self.addFile().0
            let message = self.syncConversation.appendMessage(with: fileMetadata) as! ZMAssetClientMessage
            
            // when
            message.update(withPostPayload: [:], updatedKeys: Set())
            
            // then
            XCTAssertEqual(message.uploadState, ZMAssetUploadState.uploadingPlaceholder)
            XCTAssertEqual(self.obfuscationTimer.runningTimersCount, 0)
        }
    }
}


// MARK: Receiving

extension ZMAssetClientMessageTests_Ephemeral {
    
    func testThatItStartsTheTimerWhenFileTransferStateIsUploaded() {
    
    }
    
    func testThatDoesNotItStartsTheTimerWhenFileTransferStateIsUploading() {
        
    }

}



