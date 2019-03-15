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
import WireTransport

private let MEGABYTE = UInt(1 * 1000 * 1000)

// MARK: ZMUser
extension ZMUser {
    private func cacheIdentifier(suffix: String?) -> String? {
        guard let userRemoteId = remoteIdentifier?.transportString(), let suffix = suffix else { return nil }
        return (userRemoteId + "-" + suffix)
    }
    
    @objc public func imageCacheKey(for size: ProfileImageSize) -> String? {
        switch size {
        case .preview:
            return cacheIdentifier(suffix: previewProfileAssetIdentifier)
        case .complete:
            return cacheIdentifier(suffix: completeProfileAssetIdentifier)
        }
    }
    
}

// MARK: NSManagedObjectContext

let NSManagedObjectContextUserImageCacheKey = "zm_userImageCacheKey"
extension NSManagedObjectContext
{
    @objc public var zm_userImageCache : UserImageLocalCache! {
        get {
            return self.userInfo[NSManagedObjectContextUserImageCacheKey] as? UserImageLocalCache
        }
        
        set {
            self.userInfo[NSManagedObjectContextUserImageCacheKey] = newValue
        }
    }
}

// MARK: Cache
@objcMembers open class UserImageLocalCache : NSObject {
    
    fileprivate let log = ZMSLog(tag: "UserImageCache")
    
    /// Cache for large user profile image
    fileprivate let largeUserImageCache : FileCache
    
    /// Cache for small user profile image
    fileprivate let smallUserImageCache : FileCache
    
    
    /// Create UserImageLocalCache
    /// - parameter location: where cache is persisted on disk. Defaults to caches directory if nil.
    public init(location: URL? = nil) {
        
        let largeUserImageCacheName = "largeUserImages"
        let smallUserImageCacheName = "smallUserImages"
        
        largeUserImageCache = FileCache(name: largeUserImageCacheName, location: location)
        smallUserImageCache = FileCache(name: smallUserImageCacheName, location: location)
        
        super.init()
    }
    
    /// Stores image in cache and returns true if the data was stored
    private func setImage(inCache cache: FileCache, cacheKey: String?, data: Data) -> Bool {
        if let resolvedCacheKey = cacheKey {
            cache.storeAssetData(data, key: resolvedCacheKey)
            return true
        }
        return false
    }
    
    /// Removes all images for user
    open func removeAllUserImages(_ user: ZMUser) {
        user.imageCacheKey(for: .complete).apply(largeUserImageCache.deleteAssetData)
        user.imageCacheKey(for: .preview).apply(smallUserImageCache.deleteAssetData)
    }
    
    open func setUserImage(_ user: ZMUser, imageData: Data, size: ProfileImageSize) {
        let key = user.imageCacheKey(for: size)
        switch size {
        case .preview:
            let stored = setImage(inCache: smallUserImageCache, cacheKey: key, data: imageData)
            if stored {
                log.info("Setting [\(user.displayName)] preview image [\(imageData)] cache key: \(String(describing: key))")
            }
        case .complete:
            let stored = setImage(inCache: largeUserImageCache, cacheKey: key, data: imageData)
            if stored {
                log.info("Setting [\(user.displayName)] complete image [\(imageData)] cache key: \(String(describing: key))")
            }
        }
    }
    
    open func userImage(_ user: ZMUser, size: ProfileImageSize, queue: DispatchQueue, completion: @escaping (_ imageData: Data?) -> Void) {
        guard let cacheKey = user.imageCacheKey(for: size) else { return completion(nil) }
        
        queue.async {
            switch size {
            case .preview:
                completion(self.smallUserImageCache.assetData(cacheKey))
            case .complete:
                completion(self.largeUserImageCache.assetData(cacheKey))
            }
        }
    }
    
    open func userImage(_ user: ZMUser, size: ProfileImageSize) -> Data? {
        guard let cacheKey = user.imageCacheKey(for: size) else { return nil }
        let data: Data?
        switch size {
        case .preview:
            data = smallUserImageCache.assetData(cacheKey)
        case .complete:
            data = largeUserImageCache.assetData(cacheKey)
        }
        if let data = data {
            log.info("Getting [\(user.displayName)] \(size == .preview ? "preview" : "complete") image [\(data)] cache key: [\(cacheKey)]")
        }

        return data
    }
    
    open func hasUserImage(_ user: ZMUser, size: ProfileImageSize) -> Bool {
        guard let cacheKey = user.imageCacheKey(for: size) else { return false }
        
        switch size {
        case .preview:
            return smallUserImageCache.hasDataForKey(cacheKey)
        case .complete:
            return largeUserImageCache.hasDataForKey(cacheKey)
        }
    }
    
}

public extension UserImageLocalCache {
    func wipeCache() {
        smallUserImageCache.wipeCaches()
        largeUserImageCache.wipeCaches()
    }
}
