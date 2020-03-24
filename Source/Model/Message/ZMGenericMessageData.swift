//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

@objcMembers public class ZMGenericMessageData: ZMManagedObject {
    
    @NSManaged open var data: Data
    @NSManaged open var message: ZMClientMessage?
    @NSManaged open var asset: ZMAssetClientMessage?
    
    @objc public static let messageKey = "message"
    @objc public static let assetKey = "asset"
    
    public override static func entityName() -> String {
        return "GenericMessageData"
    }
    
    public override var modifiedKeys: Set<AnyHashable>? {
        get {
            return Set()
        } set {
            // do nothing
        }
    }
    
    public func setModifiedKeys(keys: Set<AnyHashable>?) {
//        NOT_USED(keys)
    }

    var genericMessage: ZMGenericMessage? {
        guard let genericMessage = ZMGenericMessageBuilder().merge(from: data).build() as? ZMGenericMessage else {
            return nil
        }
        return genericMessage
    }
    
    var underlyingMessage: GenericMessage? {
        do {
            let genericMessage = try GenericMessage(serializedData: data)
            return genericMessage
        } catch {
            return nil
        }
    }
}
