//
//  GenericMessage+UpdateEvent.swift
//  WireDataModel
//
//  Created by David Henner on 11.02.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension GenericMessage {
    public init?(from updateEvent: ZMUpdateEvent) {
        let base64Content: String?
        
        switch updateEvent.type {
        case .conversationClientMessageAdd:
            base64Content = updateEvent.payload.string(forKey: "data")
        case .conversationOtrMessageAdd:
            base64Content = updateEvent.payload.dictionary(forKey: "data")?.string(forKey: "text")
        case .conversationOtrAssetAdd:
            base64Content = updateEvent.payload.dictionary(forKey: "data")?.string(forKey: "info")
        default:
            return nil
        }
        
        var message = GenericMessage(withBase64String: base64Content)
        
        if case .external? = message?.content {
            message = GenericMessage(from: updateEvent, withExternal: message!.external)
        }

        guard message != nil else { return nil }
        self = message!
    }
}

extension Dictionary {
    func string(forKey key: String) -> String? {
        return (self as NSDictionary).string(forKey: key)
    }
    
    func optionalString(forKey key: String) -> String? {
        return (self as NSDictionary).optionalString(forKey: key)
    }
    
    func dictionary(forKey key: String) -> [String: AnyObject]? {
        return (self as NSDictionary).dictionary(forKey: key)
    }
}
