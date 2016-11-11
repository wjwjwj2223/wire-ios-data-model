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
import XCTest

class OtrBaseTest: XCTestCase {
    
    var someOTRFolder : URL {
        return (try! FileManager.default.url(for: FileManager.SearchPathDirectory.applicationSupportDirectory,
                                             in: FileManager.SearchPathDomainMask.userDomainMask,
                                             appropriateFor: nil,
                                             create: false)).appendingPathComponent("test-OTR-folder")
    }
    
    override func setUp() {
        super.setUp()
        self.cleanOTRFolder()
    }
    
    func cleanOTRFolder() {
        let fm = FileManager.default
        
        //clean stored cryptobox files
        _ = try? fm.removeItem(at: someOTRFolder)
        
        for url in EncryptionKeysStore.legacyOtrDirectories {
            _ = try? fm.removeItem(atPath: url.path)
        }
        
        Thread.sleep(forTimeInterval: 0.1) // disk is slow
    }
    
    override func tearDown() {
        self.cleanOTRFolder()
    }
}
