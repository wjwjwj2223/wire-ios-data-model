//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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

extension ZMConversation {
    
    @objc
    public var isFavorite: Bool {
        set {
            guard let managedObjectContext = managedObjectContext else { return }
            
            let favoriteLabel = Label.fetchOrCreateFavoriteLabel(in: managedObjectContext)
            
            if newValue {
                assignLabel(favoriteLabel)
            } else {
                removeLabel(favoriteLabel)
            }
        }
        get {
            return labels.any({ $0.kind == .favorite })
        }
    }
    
    @objc
    public func moveToFolder(_ folder: Label) {
        guard folder.kind == .folder else { return }
        
        removeFromFolder()
        assignLabel(folder)
    }
    
    @objc
    public func removeFromFolder() {
        let existingFolders = labels.filter({ $0.kind == .folder })
        labels.subtract(existingFolders)
    }
    
    func assignLabel(_ label: Label) {
        labels.insert(label)
    }
    
    func removeLabel(_ label: Label) {
        labels.remove(label)
    }
    
}