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
import Cryptobox


public enum UserClientKeyStoreError: Error {
    case canNotGeneratePreKeys
    case preKeysCountNeedsToBePositive
}

public class EncryptionKeysStore {
    
    // Max prekey ID that can be generated
    public static let MaxPreKeyID : UInt16 = UInt16.max-1;
    
    // folder name for key store
    static fileprivate let otrFolderPrefix = "otr"
	
	// URL of the file storage
    public private(set) var cryptoboxDirectoryURL : URL
    
    private(set) public var encryptionContext : EncryptionContext
    
    fileprivate weak var managedObjectContext : NSManagedObjectContext?
    
    public init(managedObjectContext: NSManagedObjectContext, in directory: URL) {
        self.managedObjectContext = managedObjectContext
		self.cryptoboxDirectoryURL = directory
        self.encryptionContext = EncryptionKeysStore.setupContext(in: directory)
    }
    
    static func setupContext(in directory: URL) -> EncryptionContext {
		
        let otrDirectoryURL = EncryptionKeysStore.createOtrDirectory(at: directory)
        let encryptionContext = EncryptionContext(path: otrDirectoryURL)
        return encryptionContext
    }
    
    public func deleteAndCreateNewIdentity() {
        let fm = FileManager.default
        _ = try? fm.removeItem(at: self.cryptoboxDirectoryURL)
        self.managedObjectContext?.lastGeneratedPrekey = nil
        self.encryptionContext = EncryptionKeysStore.setupContext(in: cryptoboxDirectoryURL)
    }
    
}

// MARK: - Directory management 
extension EncryptionKeysStore {

    /// Legacy URL for cryptobox storage (transition phase)
    static public var legacyOtrDirectories : [URL] {
		return [
			(try! FileManager.default.url(for: FileManager.SearchPathDirectory.libraryDirectory, 
										in: FileManager.SearchPathDomainMask.userDomainMask, 
										appropriateFor: nil, 
										create: false)
			).appendingPathComponent(otrFolderPrefix),
			(try! FileManager.default.url(for: FileManager.SearchPathDirectory.applicationSupportDirectory, 
										in: FileManager.SearchPathDomainMask.userDomainMask, 
										appropriateFor: nil, 
										create: false)
			).appendingPathComponent(otrFolderPrefix)
		]
    }
    
    /// Creates and return the directory for cryptobox storage
    /// If the folder exists already, it will return it
    static fileprivate func createOtrDirectory(at url: URL) -> URL {
        
        self.createOrMigrateFolder(to: url)
        
        do {
            try (url as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
        
            let attributes = [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        }
        catch {
            fatal("Unable to set properties on otrDirectory: \(error)")
        }
        return url
    }
    
    /// Creates or migrate the cryptobox folder
    static private func createOrMigrateFolder(to url: URL) {
    
        defer { removeOldIdentityFolder() }
        
        guard !FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        
        for folder in self.legacyOtrDirectories {
            if FileManager.default.fileExists(atPath: folder.path) {
                do {
                    try FileManager.default.moveItem(at: folder, to: url)
                } catch {
                    fatal("Cannot move otr to shared container \(error)")
                }
                return
            }
        }
            
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatal("Unable to initialize otrDirectory = error: \(error)")
        }
    }
    
    /// Legacy URL for cryptobox storage (transition phase)
    private static var arePreviousOTRDirectoriesPresent : Bool {
        for folder in self.legacyOtrDirectories {
            if FileManager.default.fileExists(atPath: folder.path) {
                return true
            }
        }
        return false
    }
    
    /// Whether we need to migrate to a new identity (legacy e2ee transition phase)
    public static var needToMigrateIdentity : Bool {
        return self.arePreviousOTRDirectoriesPresent
    }
    
    /// Remove the old legacy identity folder
    static func removeOldIdentityFolder() {
        for folder in self.legacyOtrDirectories {
            guard FileManager.default.fileExists(atPath: folder.path) else {
                continue
            }
            do {
                try FileManager.default.removeItem(atPath: folder.path)
            }
            catch {
                // if it's still there, we failed to delete. Critical error.
                if FileManager.default.fileExists(atPath: folder.path) {
                    fatal("Failed to remove identity from previous folder: \(error)")
                }
            }
        }
    }
}

// MARK: - Prekey generation
extension EncryptionKeysStore : KeyStore {
    
    public func lastPreKey() throws -> String {
        var error: NSError?
        if self.managedObjectContext?.lastGeneratedPrekey == nil {
            encryptionContext.perform({ [weak self] (sessionsDirectory) in
                guard let strongSelf = self  else { return }
                do {
                    strongSelf.managedObjectContext?.lastGeneratedPrekey = try sessionsDirectory.generateLastPrekey()
                } catch let anError as NSError {
                    error = anError
                }
                })
        }
        if let error = error {
            throw error
        }
        return self.managedObjectContext!.lastGeneratedPrekey!
    }
    
    /// Generates prekeys in a range. This should not be called more than once
    /// for a given range, or the previously generated prekeys will be invalidated.
    public func generatePreKeys(_ count: UInt16, start: UInt16) throws -> [(id: UInt16, prekey: String)] {
        if count > 0 {
            var error : Error?
            var newPreKeys : [(id: UInt16, prekey: String)] = []
            
            let range = preKeysRange(count, start: start)
            encryptionContext.perform({(sessionsDirectory) in
                do {
                    newPreKeys = try sessionsDirectory.generatePrekeys(range)
                    if newPreKeys.count == 0 {
                        error = UserClientKeyStoreError.canNotGeneratePreKeys
                    }
                }
                catch let anError as NSError {
                    error = anError
                }
            })
            if let error = error {
                throw error
            }
            return newPreKeys
        }
        throw UserClientKeyStoreError.preKeysCountNeedsToBePositive
    }
    
    fileprivate func preKeysRange(_ count: UInt16, start: UInt16) -> CountableRange<UInt16> {
        if start >= EncryptionKeysStore.MaxPreKeyID-count {
            return CountableRange(0..<count)
        }
        return CountableRange(start..<(start + count))
    }
    
}

// MARK: - Context singleton
extension NSManagedObjectContext {
    
    fileprivate static let encryptionKeysStoreKey = "ZMUserClientKeysStore" as NSString
    
    private static let lastPrekeyKey = "ZMUserClientKeyStore_LastPrekey" as NSString
    
    @objc(setupUserKeyStoreForDirectory:)
    public func setupUserKeyStore(for directory: URL) -> Void
    {
        if !self.zm_isSyncContext {
            fatal("Can't initiliazie crypto box on non-sync context")
        }
        
        let sharedDirectory = directory.appendingPathComponent(EncryptionKeysStore.otrFolderPrefix)

        let newKeyStore = EncryptionKeysStore(managedObjectContext: self, in: sharedDirectory)
        self.userInfo.setObject(newKeyStore, forKey: NSManagedObjectContext.encryptionKeysStoreKey)
    }
    
    /// Returns the cryptobox instance associated with this managed object context
    public var zm_cryptKeyStore : EncryptionKeysStore! {
        if !self.zm_isSyncContext {
            fatal("Can't access key store: Currently not on sync context")
        }
        let keyStore = self.userInfo.object(forKey: NSManagedObjectContext.encryptionKeysStoreKey)
        if let keyStore = keyStore as? EncryptionKeysStore {
            return keyStore
        } else {
            fatal("Can't access key store: not keystore found.")
        }
        
    }
	
    /// this method is intended for testing. It will inject a custom key store in the context
    public func test_injectCryptKeyStore(_ keyStore: KeyStore) {
        self.userInfo.setObject(keyStore, forKey: NSManagedObjectContext.encryptionKeysStoreKey)
    }
    
    public func zm_tearDownCryptKeyStore() {
        self.userInfo.removeObject(forKey: NSManagedObjectContext.encryptionKeysStoreKey)
    }
	
    // Last generated prekey
    fileprivate var lastGeneratedPrekey : String? {
        
        get {
            return self.userInfo.object(forKey: NSManagedObjectContext.lastPrekeyKey) as? String
        }
        
        set {
            if let value = newValue {
                self.userInfo.setObject(value, forKey: NSManagedObjectContext.lastPrekeyKey)
            } else {
                self.userInfo.removeObject(forKey: NSManagedObjectContext.lastPrekeyKey)
            }
        }
    }
}
