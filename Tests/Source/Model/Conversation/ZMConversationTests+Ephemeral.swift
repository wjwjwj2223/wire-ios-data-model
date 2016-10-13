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


class ZMConversationMessageDestructionTimeoutTests : XCTestCase {

    func testThatItReturnsTheCorrectTimeouts(){
        
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.none.timeInterval, 0)
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.fiveSeconds.timeInterval, 5)
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.fifteenSeconds.timeInterval, 15)
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.oneMinute.timeInterval, 60)
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.fiveMinutes.timeInterval, 300)
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.fifteenMinutes.timeInterval, 1500)
    }
    
    func testThatItReturnsTheClosestTimeOut() {
        
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.closestTimeout(for: -2), 0)
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.closestTimeout(for: 5), 5)
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.closestTimeout(for: 10), 5)
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.closestTimeout(for: 55), 60)
        XCTAssertEqual(ZMConversationMessageDestructionTimeout.closestTimeout(for: 1501), 1500)
    }

}


class ZMConversationTests_Ephemeral : BaseZMMessageTests {

    func testThatItDoesNotAllowSettingTimeoutsOnGroupConversations(){
        // given
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.conversationType = .group
        
        // when
        conversation.updateMessageDestructionTimeout(timeout: .fiveSeconds)
        
        // then
        XCTAssertEqual(conversation.messageDestructionTimeout, 0)
    }

    
    func testThatItAllowsSettingTimeoutsOnOneOnOneConversations(){
        // given
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.conversationType = .oneOnOne
        
        // when
        conversation.updateMessageDestructionTimeout(timeout: .fiveSeconds)
        
        // then
        XCTAssertEqual(conversation.messageDestructionTimeout, 5)
    }
    
}

