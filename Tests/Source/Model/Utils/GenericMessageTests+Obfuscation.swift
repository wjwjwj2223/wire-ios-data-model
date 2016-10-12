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

import Foundation
@testable import ZMCDataModel

class ZMGenericMessageTests_Obfuscation : XCTestCase {
    // TODO Sabine: ImageAssets & Tweet
    
    func testThatItObfuscatesTextMessages(){
        // given
        let text = "foo"
        let message = ZMGenericMessage.message(text: text, nonce: "bar", expiresAfter: NSNumber(value: 1.0))
        
        // when
        let obfuscatedMessage = message.obfuscatedMessage()
        
        // then
        XCTAssertNotEqual(obfuscatedMessage?.text.content, text)
        XCTAssertNotNil(obfuscatedMessage?.hasText())
    }
    
    func testThatItDoesNotObfuscateNonEphemeralTextMessages(){
        // given
        let text = "foo"
        let message = ZMGenericMessage.message(text: text, nonce: "bar")
        
        // when
        let obfuscatedMessage = message.obfuscatedMessage()
        
        // then
        XCTAssertNil(obfuscatedMessage)
    }
    
    func testThatItObfuscatesLinkPreviews(){
        // given
        let title = "title"
        let summary = "summary"
        let permURL = "www.example.com/permanent"
        let origURL = "www.example.com/original"
        let text = "foo www.example.com/original"
        let offset : Int32 = 4

        let linkPreview = ZMLinkPreview.linkPreview(withOriginalURL: origURL, permanentURL: permURL, offset: offset, title: title, summary: summary, imageAsset: nil)
        let genericMessage = ZMGenericMessage.message(text: text, linkPreview: linkPreview, nonce: "qwerty", expiresAfter: NSNumber(value:20))
        
        // when
        let obfuscated =  genericMessage.obfuscatedMessage()
        
        // then
        guard let obfuscatedLinkPreview = obfuscated?.linkPreviews.first else { return XCTFail()}
        
        // then
        let obfText = obfuscated!.text.content!
        let obfOrgURL = obfText.substring(from: obfText.index(obfText.startIndex, offsetBy:4))
        XCTAssertNotEqual(obfuscatedLinkPreview.url, origURL)
        XCTAssertEqual(obfuscatedLinkPreview.url, obfOrgURL)
        XCTAssertEqual(obfuscatedLinkPreview.urlOffset, offset)
        XCTAssertTrue(obfuscatedLinkPreview.hasArticle())
        XCTAssertNotEqual(obfuscatedLinkPreview.article?.permanentUrl, permURL)
        XCTAssertNotEqual(obfuscatedLinkPreview.article?.permanentUrl.characters.count, 0)
        XCTAssertNotEqual(obfuscatedLinkPreview.article?.title, title)
        XCTAssertNotEqual(obfuscatedLinkPreview.article?.title.characters.count, 0)
        XCTAssertNotEqual(obfuscatedLinkPreview.article?.summary, summary)
        XCTAssertNotEqual(obfuscatedLinkPreview.article?.summary.characters.count, 0)
    }

    func testThatItObfuscatesAssetsImageContent(){
        // given
        let original = ZMAssetOriginal.original(withSize: 1000, mimeType: "image", name: "foo")
        let remoteData = ZMAssetRemoteData.remoteData(withOTRKey: Data(), sha256: Data(), assetId: "assetID", assetToken: "assetToken")
        let imageMetaData = ZMAssetImageMetaData.imageMetaData(withWidth: 30, height: 40)
        let imageMetaDataBuilder = imageMetaData.toBuilder()!
        imageMetaDataBuilder.setTag("bar")
        
        let preview = ZMAssetPreview.preview(withSize: 2000, mimeType: "video", remoteData: remoteData, imageMetaData: imageMetaDataBuilder.build())
        let asset  = ZMAsset.asset(withOriginal: original, preview: preview)
        let genericMessage = ZMGenericMessage.genericMessage(asset: asset, messageID: "sdgfhgjkl", expiresAfter: NSNumber(value:20))
        
        // when
        let obfuscated =  genericMessage.obfuscatedMessage()
        
        // then
        guard let obfuscatedAsset = obfuscated?.asset else { return XCTFail()}
        
        // then
        XCTAssertTrue(obfuscatedAsset.hasOriginal())
        XCTAssertEqual(obfuscatedAsset.original.size, 10)
        XCTAssertEqual(obfuscatedAsset.original.mimeType, "image")
        XCTAssertEqual(obfuscatedAsset.preview.size, 10)
        XCTAssertEqual(obfuscatedAsset.preview.mimeType, "video")
        XCTAssertEqual(obfuscatedAsset.preview.image.width, 30)
        XCTAssertEqual(obfuscatedAsset.preview.image.height, 40)
        XCTAssertEqual(obfuscatedAsset.preview.image.tag, "bar")
        XCTAssertFalse(obfuscatedAsset.preview.hasRemote())
    }
    
    func testThatItObfuscatesAssetsVideoContent() {
        // given
        let original = ZMAssetOriginal.original(withSize: 200, mimeType: "video", name: "foo", videoDurationInMillis: 500, videoDimensions: CGSize(width: 305, height: 200))
        
        let asset  = ZMAsset.asset(withOriginal: original, preview: nil)
        let genericMessage = ZMGenericMessage.genericMessage(asset: asset, messageID: "sdgfhgjkl", expiresAfter: NSNumber(value:20))
        
        // when
        let obfuscated =  genericMessage.obfuscatedMessage()
        
        // then
        guard let obfuscatedAsset = obfuscated?.asset else { return XCTFail()}
        
        // then
        XCTAssertTrue(obfuscatedAsset.hasOriginal())
        XCTAssertEqual(obfuscatedAsset.original.size, 10)
        XCTAssertEqual(obfuscatedAsset.original.mimeType, "video")
        XCTAssertNotEqual(obfuscatedAsset.original.name, "foo")

        XCTAssertTrue(obfuscatedAsset.original.hasVideo())
        XCTAssertFalse(obfuscatedAsset.original.video.hasWidth())
        XCTAssertFalse(obfuscatedAsset.original.video.hasHeight())
        XCTAssertFalse(obfuscatedAsset.original.video.hasDurationInMillis())
    }
    
    func checkThatItObfuscatesAudioMessages() {
        // given
        let original = ZMAssetOriginal.original(withSize: 200, mimeType: "audio", name: "foo", audioDurationInMillis: 300, normalizedLoudness: [2.9])
        let asset  = ZMAsset.asset(withOriginal: original, preview: nil)
        let genericMessage = ZMGenericMessage.genericMessage(asset: asset, messageID: "sdgfhgjkl", expiresAfter: NSNumber(value:20))
        
        // when
        let obfuscated =  genericMessage.obfuscatedMessage()
        
        // then
        guard let obfuscatedAsset = obfuscated?.asset else { return XCTFail()}
        
        XCTAssertTrue(obfuscatedAsset.hasOriginal())
        XCTAssertEqual(obfuscatedAsset.original.size, 10)
        XCTAssertEqual(obfuscatedAsset.original.mimeType, "audio")
        XCTAssertNotEqual(obfuscatedAsset.original.name, "foo")
        
        XCTAssertTrue(obfuscatedAsset.original.hasAudio())
        XCTAssertFalse(obfuscatedAsset.original.audio.hasDurationInMillis())
        XCTAssertFalse(obfuscatedAsset.original.audio.hasNormalizedLoudness())
    }
    
    func testThatItObfuscatesLocationMessages() {
        // given
        let location  = ZMLocation.location(withLatitude: 2.0, longitude: 3.0)
        let message = ZMGenericMessage.genericMessage(location: location, messageID: "bar", expiresAfter: NSNumber(value:20))
        
        // when
        let obfuscatedMessage = message.obfuscatedMessage()
        
        // then
        XCTAssertNotNil(obfuscatedMessage?.locationData)
        XCTAssertEqual(obfuscatedMessage?.location.longitude, 0.0)
        XCTAssertEqual(obfuscatedMessage?.location.latitude, 0.0)
    }
    
}
