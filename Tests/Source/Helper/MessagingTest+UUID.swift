//
//  MessagingTest+UUID.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 13/09/16.
//  Copyright © 2016 Wire Swiss GmbH. All rights reserved.
//

import Foundation
import ZMTesting


public extension UUID {

    public static func create() -> UUID {
            return UUID.create() as UUID
    }
}


public extension Date {

    public func transportString() -> String {
        return (self as NSDate).transportString()!
    }
    
}


public extension Data {

    static func secureRandomData(ofLength length: UInt) -> Data {
        return NSData.secureRandomData(ofLength: length)!
    }

}
