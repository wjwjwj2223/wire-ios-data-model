//
//  NSManagedObjectContext+FetchRequest.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 12/09/16.
//  Copyright © 2016 Wire Swiss GmbH. All rights reserved.
//

import Foundation



public extension NSManagedObjectContext {
    
    /// Executes a fetch request and asserts in case of error
    func executeFetchOrAssert<T : NSFetchRequestResult>(request: NSFetchRequest<T>) -> [T] {
        do {
            let result = try fetch(request)
            return result
        } catch let error {
            fatal("Error in fetching \(error.localizedDescription)")
        }
    }
}
