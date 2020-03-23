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

extension ZMClientMessage {
    
    public override var genericMessage: ZMGenericMessage? {
        return genericClientMessage
    }
    
    public var genericClientMessage: ZMGenericMessage? {
        guard !isZombieObject else { return nil }
        
        if self.cachedGenericMessage == nil {
            self.cachedGenericMessage = genericMessageFromDataSet()
        }
        return self.cachedGenericMessage
    }
    
    private func genericMessageFromDataSet() -> ZMGenericMessage? {
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
    
    public var underlyingMessage: GenericMessage? {
        guard !isZombieObject else { return nil }
        
        if self.cachedUnderlyingMessage == nil {
            self.cachedUnderlyingMessage = self.underlyingMessageMergedFromDataSet()
        }
        return self.cachedUnderlyingMessage
    }
    
    private func underlyingMessageMergedFromDataSet() -> GenericMessage? {
        let filteredData = self.dataSet
            .compactMap { $0 as? ZMGenericMessageData }
            .compactMap { $0.underlyingMessage }
            .filter { $0.knownMessage && $0.imageAssetData == nil }
            .compactMap { try? $0.serializedData() }
        guard !filteredData.isEmpty else { return nil }
        
        var message = GenericMessage()
        filteredData.forEach {
            try? message.merge(serializedData: $0)
        }
        return message
    }
    
    @objc(addData:)
    public func add(_ data: Data?) {
        guard let data = data else {
            return
        }
        let messageData = mergeWithExistingData(data)
        
        if (self.nonce == nil) {
            self.nonce = UUID(uuidString: messageData?.genericMessage?.messageId ?? "")
        }
        updateCategoryCache()
        setLocallyModifiedKeys([#keyPath(ZMClientMessage.dataSet)])
    }
    
    public override func update(with message: ZMGenericMessage, updateEvent: ZMUpdateEvent, initialUpdate: Bool) {
        if initialUpdate {
            add(message.data())
            updateNormalizedText()
        } else {
            applyLinkPreviewUpdate(message, from: updateEvent)
        }
    }
}

// MARK: Message data
extension ZMClientMessage: ZMKnockMessageData {
    
    public override var textMessageData: ZMTextMessageData? {
        let isTextMessage = self.genericMessage?.textData != nil
        return isTextMessage ? self : nil
    }
    
    public override var imageMessageData: ZMImageMessageData? {
        return nil
    }
    
    public override var knockMessageData: ZMKnockMessageData? {
        let isKnockMessage = self.genericMessage?.knockData != nil
        return isKnockMessage ? self : nil
    }
    
    public override var fileMessageData: ZMFileMessageData? {
        return nil
    }
    
    public override var locationMessageData: LocationMessageData? {
        switch underlyingMessage?.content {
        case .location(_)?:
            return self
        case .ephemeral(let data)?:
            switch data.content {
            case .location(_)?:
                return self
            default:
                return nil
            }
            
        default:
            return nil
        }
    }
}
