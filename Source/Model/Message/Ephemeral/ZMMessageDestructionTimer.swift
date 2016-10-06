//
//  ZMMessageDestructionTimer.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 28/09/16.
//  Copyright © 2016 Wire Swiss GmbH. All rights reserved.
//

import Foundation


let MessageDeletionTimerKey = "MessageDeletionTimer"
let MessageObfuscationTimerKey = "MessageObfuscationTimer"

public extension NSManagedObjectContext {
    
    public var zm_messageDeletionTimer : ZMMessageDestructionTimer {
        if !zm_isUserInterfaceContext {
            preconditionFailure("MessageDeletionTimerKey should be started only on the uiContext")
        }
        if let timer = userInfo[MessageDeletionTimerKey] as? ZMMessageDestructionTimer {
            return timer
        }
        let timer = ZMMessageDestructionTimer(managedObjectContext: self)
        userInfo[MessageDeletionTimerKey] = timer
        return timer
    }
    
    public var zm_messageObfuscationTimer : ZMMessageDestructionTimer {
        if !zm_isSyncContext {
            preconditionFailure("MessageObfuscationTimer should be started only on the syncContext")
        }
        if let timer = userInfo[MessageObfuscationTimerKey] as? ZMMessageDestructionTimer {
            return timer
        }
        let timer = ZMMessageDestructionTimer(managedObjectContext: self)
        userInfo[MessageObfuscationTimerKey] = timer
        return timer
    }
    
    /// Tears down zm_messageObfuscationTimer and zm_messageDeletionTimer
    /// Call inside a performGroupedBlock(AndWait) when calling it from another context
    public func zm_teardownMessageObfuscationTimer() {
        if let timer = userInfo[MessageObfuscationTimerKey] as? ZMMessageDestructionTimer {
            timer.tearDown()
            userInfo.removeObject(forKey: MessageObfuscationTimerKey)
        }
    }
    
    /// Tears down zm_messageDeletionTimer
    /// Call inside a performGroupedBlock(AndWait) when calling it from another context
    public func zm_teardownMessageDeletionTimer() {
        if let timer = userInfo[MessageDeletionTimerKey] as? ZMMessageDestructionTimer {
            timer.tearDown()
            userInfo.removeObject(forKey: MessageDeletionTimerKey)
        }
    }
}

enum MessageDestructionType : String {
    static let UserInfoKey = "destructionType"
    
    case obfuscation, deletion
}


public class ZMMessageDestructionTimer : ZMMessageTimer {

    override init(managedObjectContext: NSManagedObjectContext!) {
        super.init(managedObjectContext: managedObjectContext)
        timerCompletionBlock = { [weak self] (message, userInfo) in
            guard let strongSelf = self, let message = message, !message.isZombieObject else { return }
            strongSelf.messageTimerDidFire(message: message, userInfo:userInfo)
        }
    }
    
    func messageTimerDidFire(message: ZMMessage, userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo as? [String : Any],
              let type = userInfo[MessageDestructionType.UserInfoKey] as? String
        else { return }
        
        switch MessageDestructionType(rawValue:type) {
        case .some(.obfuscation):
            message.obfuscate()
        case .some(.deletion):
            ZMMessage.deleteForEveryone(message)
        default:
            return
        }
        moc.saveOrRollback()
    }
    
    public func startObfuscationTimer(message: ZMMessage, timeout: TimeInterval) {
        let fireDate = Date().addingTimeInterval(timeout)
        start(forMessageIfNeeded: message,
              fire: fireDate,
              userInfo: [MessageDestructionType.UserInfoKey : MessageDestructionType.obfuscation.rawValue])
    }
    
    public func startDeletionTimer(message: ZMMessage, timeout: TimeInterval) {
        let fireDate = Date().addingTimeInterval(timeout)
        start(forMessageIfNeeded: message,
              fire: fireDate,
              userInfo: [MessageDestructionType.UserInfoKey : MessageDestructionType.deletion.rawValue])
    }

}


