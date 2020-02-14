//
//  GenericMessageTests+External.swift
//  WireDataModelTests
//
//  Created by David Henner on 14.02.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation
@testable import WireDataModel

class GenericMessageTests_External: XCTestCase {
    var sut: GenericMessage!
    
    override func setUp() {
        super.setUp()
        let text = Text.with() {
            $0.content = "She sells sea shells"
        }
        
        sut = GenericMessage.with() {
            $0.text = text
            $0.messageID = NSUUID.create()!.transportString()
        }
    }
    
    override func tearDown() {
        super.tearDown()
        sut = nil
    }
    
    func testThatItEncryptsTheMessageAndReturnsTheCorrectKeyAndDigest() {
        // given / when
        let dataWithKeys = GenericMessage.encryptedDataWithKeys(from: sut)
        XCTAssertNotNil(dataWithKeys)
        
        let keysWithDigest = dataWithKeys!.keys
        let data = dataWithKeys!.data
        
        // then
        XCTAssertEqual(data?.zmSHA256Digest(), keysWithDigest?.sha256)
        XCTAssertEqual(data?.zmDecryptPrefixedPlainTextIV(key: keysWithDigest!.aesKey), try? sut.serializedData())
    }
    
    func testThatItUsesADifferentKeyForEachCall() {
        // given / when
        let firstDataWithKeys = GenericMessage.encryptedDataWithKeys(from: sut)
        let secondDataWithKeys = GenericMessage.encryptedDataWithKeys(from: sut)
        XCTAssertNotNil(firstDataWithKeys)
        XCTAssertNotNil(secondDataWithKeys)
        let firstEncrypted = firstDataWithKeys?.data.zmDecryptPrefixedPlainTextIV(key: firstDataWithKeys!.keys.aesKey)
        let secondEncrypted = secondDataWithKeys?.data.zmDecryptPrefixedPlainTextIV(key: secondDataWithKeys!.keys.aesKey)
        
        // then
        XCTAssertNotEqual(firstDataWithKeys?.keys.aesKey, secondDataWithKeys?.keys.aesKey)
        XCTAssertNotEqual(firstDataWithKeys, secondDataWithKeys)
        XCTAssertEqual(firstEncrypted, try? sut.serializedData())
        XCTAssertEqual(secondEncrypted, try? sut.serializedData())
    }
    
    func testThatDifferentKeysAreNotConsideredEqual() {
        // given / when
        let firstKeys = GenericMessage.encryptedDataWithKeys(from: sut)?.keys
        let secondKeys = GenericMessage.encryptedDataWithKeys(from: sut)?.keys
        
        // then
        XCTAssertFalse(firstKeys?.aesKey == secondKeys?.aesKey)
        XCTAssertFalse(firstKeys?.sha256 == secondKeys?.sha256)
        XCTAssertEqual(firstKeys, firstKeys)
        XCTAssertNotEqual(firstKeys, secondKeys)
    }
}
