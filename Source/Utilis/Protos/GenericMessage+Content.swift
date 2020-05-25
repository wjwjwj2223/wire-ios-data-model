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

// MARK: - GenericMessage

public extension GenericMessage {
    var hasText: Bool {
        guard let _ = messageData as? Text else {
            let ephemeral = messageData as? Ephemeral
            return ephemeral?.hasText ?? false
        }
        return true
    }
    
    var hasConfirmation: Bool {
        return (messageData as? Confirmation) != nil ? true : false
    }
    
    var hasReaction: Bool {
        return (messageData as? Reaction) != nil ? true : false
    }
    
    var hasAsset: Bool {
        guard let _ = messageData as? WireProtos.Asset else {
            let ephemeral = messageData as? Ephemeral
            return ephemeral?.hasAsset ?? false
        }
        return true
    }
    
    var hasEphemeral: Bool {
        return (messageData as? Ephemeral) != nil ? true : false
    }
    
    var hasClientAction: Bool {
        return (messageData as? ClientAction) != nil ? true : false
    }
    
    var hasCleared: Bool {
        return (messageData as? Cleared) != nil ? true : false
    }
    
    var hasLastRead: Bool {
        return (messageData as? LastRead) != nil ? true : false
    }
    
    var hasKnock: Bool {
        guard let _ = messageData as? Knock else {
            let ephemeral = messageData as? Ephemeral
            return ephemeral?.hasKnock ?? false
        }
        return true
    }
    
    var hasExternal: Bool {
        return (messageData as? External) != nil ? true : false
    }
    
    var hasAvailability: Bool {
        return (messageData as? WireProtos.Availability) != nil ? true : false
    }
    
    var hasEdited: Bool {
        return (messageData as? MessageEdit) != nil ? true : false
    }
    
    var hasDeleted: Bool {
        return (messageData as? MessageDelete) != nil ? true : false
    }
    
    var hasCalling: Bool {
        return (messageData as? Calling) != nil ? true : false
    }
    
    var hasHidden: Bool {
        return (messageData as? MessageHide) != nil ? true : false
    }
    
    var hasLocation: Bool {
        guard let _ = messageData as? Location else {
            let ephemeral = messageData as? Ephemeral
            return ephemeral?.hasLocation ?? false
        }
        return true
    }
}

// MARK: - Ephemeral

public extension Ephemeral {
    var hasAsset: Bool {
        return (messageData as? WireProtos.Asset) != nil ? true : false
    }
    
    var hasKnock: Bool {
        return (messageData as? Knock) != nil ? true : false
    }

    var hasLocation: Bool {
        return (messageData as? Location) != nil ? true : false
    }
    
    var hasText: Bool {
        return (messageData as? Text) != nil ? true : false
    }
}
