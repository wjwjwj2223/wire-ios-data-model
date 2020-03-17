//
//  ZMClientMessage+Underlying1.swift
//  WireDataModel
//
//  Created by Katerina on 16.03.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension ZMClientMessage {
    override open func obfuscate() {
        super.obfuscate()
        if self.underlyingMessage?.knockData == nil {
            guard let obfuscatedMessage = self.underlyingMessage?.obfuscatedMessage() else { return }
            deleteContent()
            do {
                let data = try obfuscatedMessage.serializedData()
                mergeWithExistingData(data)
            }  catch {}
        }
    }
    
    private func deleteContent() {
        self.dataSet.map { $0 as! ZMGenericMessageData }.forEach {
            $0.managedObjectContext?.delete($0)
        }
        self.dataSet = NSOrderedSet()
        self.normalizedText = nil
        self.quote = nil
    }
    
    @objc(mergeWithExistingData:)
    func mergeWithExistingData(_ data: Data) -> ZMGenericMessageData? {
        let existingMessageData = self.dataSet
            .compactMap { $0 as? ZMGenericMessageData }
            .first
        
        guard existingMessageData != nil else {
            return createNewGenericMessage(with: data)
            
        }
        existingMessageData?.data = data
        return existingMessageData
    }
    
    private func createNewGenericMessage(with data: Data) -> ZMGenericMessageData? {
        guard let moc = self.managedObjectContext else { fatalError() }
        let messageData = ZMGenericMessageData.insertNewObject(in: moc)
        messageData.data = data
        messageData.message = self
        return messageData
    }
}
