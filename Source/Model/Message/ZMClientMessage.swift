//
//  ZMClientMessage.swift
//  WireDataModel
//
//  Created by Katerina on 17.03.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension ZMClientMessage {
    
    // Private implementation
//    @NSManaged fileprivate var updatedTimestamp: Data
//    @NSManaged fileprivate var linkPreviewState: ZMLinkPreviewState
    
    public override static func entityName() -> String {
        return "ClientMessage"
    }
    
    open override var ignoredKeys: Set<AnyHashable>? {
        return (super.ignoredKeys ?? Set())
            .union([
                #keyPath(updatedTimestamp) //FIX ME
                ])
        
    }
    
    func updatedAt() -> Date? {
        return self.updatedTimestamp
    }
    
    public override var hashOfContent: Data? {
        guard let serverTimestamp = serverTimestamp else { return nil }
        
        return genericMessage?.hashOfContent(with: serverTimestamp)
    }
    
    @objc(addData:)
    func add(_ data: Data?) {
        guard let data = data else {
            return
        }
        let messageData = mergeWithExistingData(data)
        self.setGenericMessage(genericMessageFromDataSet())
        
        if (self.nonce == nil) {
            self.nonce = UUID(uuidString: messageData?.genericMessage?.messageId ?? "")
        }
        updateCategoryCache()
//        setLocallyModifiedKeys([NSSet.setValuesForKeys(ZMClientMessage.dataSet)])
    }
    
    @objc(setGenericMessage:)
    func setGenericMessage(_ genericMessage: ZMGenericMessage?) { // FIX ME and comment
        //    if ([genericMessage knownMessage] && genericMessage.imageAssetData == nil) {
        //    _genericMessage = genericMessage;
        //    }
    }
    
    @objc func genericMessageFromDataSet() -> ZMGenericMessage? { // FIX ME - private
        let filteredMessages = self.dataSet
            .compactMap { ($0 as? ZMGenericMessageData)?.genericMessage }
            .filter{ $0.knownMessage() && $0.imageAssetData == nil }
        
        guard !filteredMessages.isEmpty else {
            return nil
        }
        
        let builder = ZMGenericMessage.builder()!
        filteredMessages.forEach { builder.merge(from: $0) }
        return builder.build()
    }
}

//- (void)addData:(NSData *)data
//{
//    if (data == nil) {
//        return;
//    }
//
//    ZMGenericMessageData *messageData = [self mergeWithExistingData:data];
//    [self setGenericMessage:self.genericMessageFromDataSet];
//
//    if (self.nonce == nil) {
//        self.nonce = [NSUUID uuidWithTransportString:messageData.genericMessage.messageId];
//    }
//
//    [self updateCategoryCache];
//    [self setLocallyModifiedKeys:[NSSet setWithObject:ClientMessageDataSetKey]];
//}
