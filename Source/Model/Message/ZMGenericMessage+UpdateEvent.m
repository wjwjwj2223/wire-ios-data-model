// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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


#import "ZMGenericMessage+UpdateEvent.h"
#import "ZMGenericMessage+External.h"
#import "ZMGenericMessage+Utils.h"
#import "WireDataModel/WireDataModel-Swift.h"

@implementation ZMGenericMessage (UpdateEvent)

+ (Class)entityClassForGenericMessage:(ZMGenericMessage *)genericMessage
{
    if (/*genericMessage.imageAssetData != nil || */genericMessage.assetData != nil) {
        return [ZMAssetClientMessage class];
    }
    
    return ZMClientMessage.class;
}

+ (Class)entityClassForPlainMessageForGenericMessage:(ZMGenericMessage *)genericMessage
{
    if (genericMessage.hasText) {
        return ZMTextMessage.class;
    }
    
    if (genericMessage.hasImage) {
        return ZMImageMessage.class;
    }
    
    if (genericMessage.hasKnock) {
        return ZMKnockMessage.class;
    }
    
    return nil;
}


@end
