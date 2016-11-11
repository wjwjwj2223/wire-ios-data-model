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


import XCTest
@testable import ZMCDataModel
import Cryptobox


class EncryptionKeysStoreTests: OtrBaseTest {
    
    var managedObjectContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
		self.cleanOTRFolder()
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    }
    
    override func tearDown() {
        self.managedObjectContext = nil
        self.cleanOTRFolder()
        super.tearDown()
    }
    
    func testThatTheOTRFolderHasBackupDisabled() {
        
        // given
        _ = EncryptionKeysStore(managedObjectContext: self.managedObjectContext, in: self.someOTRFolder)
        guard let values = try? self.someOTRFolder.resourceValues(forKeys: Set(arrayLiteral: URLResourceKey.isExcludedFromBackupKey)) else {return XCTFail()}

        // then
        XCTAssertTrue(values.isExcludedFromBackup!)
    }
    
    func testThatItCanGenerateMoreKeys() {
        
        // given
        let sut = EncryptionKeysStore(managedObjectContext: self.managedObjectContext, in: self.someOTRFolder)
        
        // when
        do {
            let newKeys = try sut.generatePreKeys(1, start: 0)
            XCTAssertNotEqual(newKeys.count, 0, "Should generate more keys")
            
        } catch let error as NSError {
            XCTAssertNil(error, "Should not return error while generating key")
            
        }
        
    }
    
    func testThatItWrapsKeysTo0WhenReachingTheMaximum() {
        // given
        let sut = EncryptionKeysStore(managedObjectContext: self.managedObjectContext, in: self.someOTRFolder)
        let maxPreKey : UInt16 = EncryptionKeysStore.MaxPreKeyID
        print(maxPreKey)
        let prekeyBatchSize : UInt16 = 50
        let startingPrekey = maxPreKey - prekeyBatchSize - 1 // -1 is to generate at least 2 batches
        let maxIterations = 2
        
        var previousMaxKeyId : UInt16 = startingPrekey
        var iterations = 0
        
        // when
        while (true) {
            var newKeys : [(id: UInt16, prekey: String)]!
            var maxKey : UInt16!
            var minKey : UInt16!
            do {
                newKeys = try sut.generatePreKeys(50, start: previousMaxKeyId)
                maxKey = newKeys.last?.id ?? 0
                minKey = newKeys.first?.id ?? 0
            } catch let error as NSError {
                XCTAssertNil(error, "Should not return error while generating key: \(error)")
                return
            }
            
            // then
            iterations += 1
            if (iterations > maxIterations) {
                XCTFail("Too many keys are generated without wrapping: \(iterations) iterations, max key is \(maxKey)")
                return
            }
            
            XCTAssertGreaterThan(newKeys.count, 0, "Should generate more keys")
            if (minKey == 0) { // it wrapped!!
                XCTAssertGreaterThan(iterations, 1)
                // success!
                return
            }
            
            XCTAssertEqual(minKey, previousMaxKeyId) // is it the right starting point?
            
            previousMaxKeyId = maxKey
            if (maxKey > EncryptionKeysStore.MaxPreKeyID) {
                XCTFail("Prekey \(maxKey) is too big")
                return
            }
            
        }
        
    }
    
    func testThatTheNonEmptyLegacyOTRFolderIsDetected() {

        for folder in EncryptionKeysStore.legacyOtrDirectories {

            XCTAssertFalse(EncryptionKeysStore.needToMigrateIdentity)
            
            // given
            try! FileManager.default.createDirectory(atPath: folder.path, withIntermediateDirectories: true, attributes: [:])
            try! "foo".data(using: String.Encoding.utf8)!.write(to: folder.appendingPathComponent("aabb013ac313"), options: Data.WritingOptions.atomic)
            
            // then
            XCTAssertTrue(EncryptionKeysStore.needToMigrateIdentity)
            
            // after
            self.cleanOTRFolder()
        }
	}
    
    func testThatEmptyLegacyOTRFolderIsDetected() {
        
        for folder in EncryptionKeysStore.legacyOtrDirectories {
            
            XCTAssertFalse(EncryptionKeysStore.needToMigrateIdentity)
            
            // given
            try! FileManager.default.createDirectory(atPath: folder.path, withIntermediateDirectories: true, attributes: [:])
            
            // then
            XCTAssertTrue(EncryptionKeysStore.needToMigrateIdentity)
            
            // after
            self.cleanOTRFolder()
        }
    }
    
    func testThatTheNonEmptyLegacyOTRFolderIsMigrated() {
        
        self.cleanOTRFolder()
        for folder in EncryptionKeysStore.legacyOtrDirectories {
            
            XCTAssertFalse(EncryptionKeysStore.needToMigrateIdentity)
            
            // given
            let text = "folder: \(folder.path)"
            let file = "aabb013ac313"
            try! FileManager.default.createDirectory(atPath: folder.path, withIntermediateDirectories: true, attributes: [:])
            try! text.data(using: String.Encoding.utf8)!.write(to: folder.appendingPathComponent(file), options: Data.WritingOptions.atomic)
            XCTAssertTrue(EncryptionKeysStore.needToMigrateIdentity)

            
            // when
            let _ = EncryptionKeysStore(managedObjectContext: self.managedObjectContext, in: self.someOTRFolder)
            
            // then
            let fooData = try! Data(contentsOf: self.someOTRFolder.appendingPathComponent(file))
            let fooString = String(data: fooData, encoding: String.Encoding.utf8)!
            XCTAssertEqual(fooString, text)
            XCTAssertFalse(EncryptionKeysStore.needToMigrateIdentity)

            
            // after
            self.cleanOTRFolder()
        }
    }
    
    func testThatEmptyLegacyOTRFolderIsMigrated() {
        
        self.cleanOTRFolder()
        for folder in EncryptionKeysStore.legacyOtrDirectories {
            
            XCTAssertFalse(EncryptionKeysStore.needToMigrateIdentity)
            
            // given
            try! FileManager.default.createDirectory(atPath: folder.path, withIntermediateDirectories: true, attributes: [:])
            XCTAssertTrue(EncryptionKeysStore.needToMigrateIdentity)
            
            
            // when
            let _ = EncryptionKeysStore(managedObjectContext: self.managedObjectContext, in: self.someOTRFolder)
            
            // then
            XCTAssertFalse(EncryptionKeysStore.needToMigrateIdentity)
            
            // after
            self.cleanOTRFolder()
        }
    }
	
    func testThatTheOTRFolderHasTheRightPath() {
        
        // given
        let sut = EncryptionKeysStore(managedObjectContext: self.managedObjectContext, in: self.someOTRFolder)
        
        // then
        XCTAssertEqual(sut.cryptoboxDirectoryURL.path, self.someOTRFolder.path)
    }
    
    func testThatItCanDeleteANonExistingOldIdentityFolder() {
        
        // when
        EncryptionKeysStore.removeOldIdentityFolder()
        
        // then
        XCTAssertFalse(EncryptionKeysStore.needToMigrateIdentity)
    }

    
    func testThatItDoesNotNeedToMigrateWhenThereIsNoLegacyFolder() {
        
        // then
        XCTAssertFalse(EncryptionKeysStore.needToMigrateIdentity)
    }    
}
