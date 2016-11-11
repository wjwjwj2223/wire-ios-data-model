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
import Cryptobox
@testable import ZMCDataModel

class CryptoBoxTest: OtrBaseTest {

    func testThatCryptoBoxFolderIsForbiddenFromBackup() {
        // when
         _ = EncryptionKeysStore.setupContext(in: self.someOTRFolder)
        
        // then
        guard let values = try? self.someOTRFolder.resourceValues(forKeys: Set(arrayLiteral: .isExcludedFromBackupKey)) else {return XCTFail()}
        
        XCTAssertTrue(values.isExcludedFromBackup!)
    }
    
    func testThatCryptoBoxFolderIsMarkedForEncryption() {
        
        // when
        _ = EncryptionKeysStore.setupContext(in: self.someOTRFolder)
        
        let attrs = try! FileManager.default.attributesOfItem(atPath: self.someOTRFolder.path)
        let fileProtectionAttr = (attrs[FileAttributeKey.protectionKey] as? String)
        
        
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            // File protection API is not available on simulator
            XCTAssertTrue(true)
        #else
            XCTAssertEqual(fileProtectionAttr, FileProtectionType.completeUntilFirstUserAuthentication)
        #endif
    }

}
