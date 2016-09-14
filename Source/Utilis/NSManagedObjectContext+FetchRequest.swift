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
    func fetchOrAssert<T : NSFetchRequestResult>(request: NSFetchRequest<T>) -> [T] where T: NSManagedObject {
        do {
//            let subRequest : NSFetchRequest<NSManagedObject> = request as! NSFetchRequest<NSManagedObject>
            let result = try fetch(request)
            return result //.flatMap{$0 as? T}
        } catch let error {
            fatal("Error in fetching \(error.localizedDescription)")
        }
    }
}
