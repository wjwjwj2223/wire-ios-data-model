//
//  GenericMessage+Obfuscation.swift
//  WireDataModel
//
//  Created by Katerina on 05.03.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

public extension String {
    
    static func randomChar() -> UnicodeScalar {
        let string = "abcdefghijklmnopqrstuvxyz"
        let chars = Array(string.unicodeScalars)
        let random = UInt.secureRandomNumber(upperBound: UInt(chars.count))
        // in this case we know random will fit inside int
        return chars[Int(random)]
    }
    
    func obfuscated() -> String {
        var obfuscatedVersion = UnicodeScalarView()
        for char in self.unicodeScalars {
            if NSCharacterSet.whitespacesAndNewlines.contains(char) {
                obfuscatedVersion.append(char)
            } else {
                obfuscatedVersion.append(String.randomChar())
            }
        }
        return String(obfuscatedVersion)
    }
}

public extension GenericMessage {
    
    func obfuscatedMessage() -> GenericMessage? {
        guard let messageID = (messageID as String?).flatMap(UUID.init) else { return nil }
        guard case .ephemeral? = self.content else { return nil }
        
        if let someText = textData {
            let content = someText.content
            let obfuscatedContent = content.obfuscated()
            var obfuscatedLinkPreviews : [LinkPreview] = []
            if linkPreviews.count > 0 {
                let offset = linkPreviews.first!.urlOffset
                let offsetIndex = obfuscatedContent.index(obfuscatedContent.startIndex, offsetBy: Int(offset), limitedBy: obfuscatedContent.endIndex) ?? obfuscatedContent.startIndex
                let originalURL = obfuscatedContent[offsetIndex...]
                obfuscatedLinkPreviews = linkPreviews.map { $0.obfuscated(originalURL: String(originalURL)) }
            }
            
            let obfuscatedText = Text.with {
                $0.content = obfuscatedContent
                $0.mentions = []
                $0.linkPreview = obfuscatedLinkPreviews
            }
            
            return GenericMessage(content: obfuscatedText, nonce: messageID)
        }
        
        if let someAsset = assetData {
            let obfuscatedAsset = someAsset.obfuscated()
            return GenericMessage(content: obfuscatedAsset, nonce: messageID)
        }
        if locationData != nil {
            let obfuscatedLocation = Location(latitude: 0.0, longitude: 0.0)
            return GenericMessage(content: obfuscatedLocation, nonce: messageID)
        }
        return nil
    }
}

extension ImageAsset {
    func obfuscated() -> ImageAsset {
        return WireProtos.ImageAsset.with({
            $0.tag = tag
            $0.width = width
            $0.height = height
            $0.originalWidth = originalWidth
            $0.originalHeight = originalHeight
            $0.mimeType = mimeType
            $0.size = 1
        })
    }
}

extension LinkPreview {
    
    func obfuscated(originalURL: String) -> LinkPreview {
        let obfTitle = hasTitle ? title.obfuscated() : ""
        let obfSummary = hasSummary ? summary.obfuscated() : ""
        let obfImage = hasImage ? image.obfuscated() : nil
        return  LinkPreview.with {
            $0.url = originalURL
            $0.permanentURL = permanentURL.obfuscated()
            $0.urlOffset = urlOffset
            $0.title = obfTitle
            $0.summary = obfSummary
            if let obfImage = obfImage {
                $0.image = obfImage
            }
            $0.tweet = tweet.obfuscated()
        }
    }
}

extension Tweet {
    func obfuscated() -> Tweet {
        let obfAuthorName = hasAuthor ? author.obfuscated() : ""
        let obfUserName = hasUsername ? username.obfuscated() : ""
        return Tweet.with({
            $0.author = obfAuthorName
            $0.username = obfUserName
        })
    }
}

extension WireProtos.Asset {
     func obfuscated() -> WireProtos.Asset {
        var assetOriginal: WireProtos.Asset.Original? = nil
        var assetPreview: WireProtos.Asset.Preview? = nil
        
        if hasOriginal {
            if original.hasRasterImage {
                let imageMetaData = WireProtos.Asset.ImageMetaData.with {
                    $0.tag = original.image.tag
                    $0.width = original.image.width
                    $0.height = original.image.height
                }
               assetOriginal?.image = imageMetaData
            }
            
            if original.hasName {
                let obfName = original.name.obfuscated()
                assetOriginal?.name = obfName
            }
            
            assetOriginal?.audio = WireProtos.Asset.AudioMetaData()
            assetOriginal?.video = WireProtos.Asset.VideoMetaData()
            
            assetOriginal?.size = 10
            assetOriginal?.mimeType = original.mimeType
        }
        
        if hasPreview  {
            let imageMetaData = WireProtos.Asset.ImageMetaData.with {
                $0.tag = preview.image.tag
                $0.width = preview.image.width
                $0.height = preview.image.height
            }
            assetPreview?.image = imageMetaData
            assetPreview?.size = 10
            assetPreview?.mimeType = preview.mimeType
        }
        return WireProtos.Asset(original: assetOriginal!, preview: assetPreview!)
    }
}
