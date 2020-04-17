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

import XCTest
@testable import WireDataModel

final class SignatureStatusTests: ZMBaseManagedObjectTest {
    var status: SignatureStatus!
    var asset: ZMAsset?
    
    override func setUp() {
        super.setUp()
        asset = createAsset()
        status = SignatureStatus(asset: asset,
                                 data: Data(),
                                 managedObjectContext: syncMOC)
    }
    
    override func tearDown() {
        asset = nil
        status = nil
        super.tearDown()
    }
    
    func testThatItChangesStatusAfterTriggerASignDocumentMethod() {
        // when
        XCTAssertEqual(status.state, .initial)
        status.signDocument()
        
        // then
        XCTAssertEqual(status.state, .waitingForConsentURL)
    }
    
    func testThatItChangesStatusAfterTriggerARetrieveSignatureMethod() {
        // when
        status.retrieveSignature()
        
        // then
        XCTAssertEqual(status.state, .waitingForSignature)
    }
    
    func testThatItTakesRequiredAssetAtributesForTheRequest() {
        XCTAssertEqual(asset?.uploaded.assetId, "id")
        XCTAssertEqual(asset?.preview.remote.assetId, "")
        
        XCTAssertEqual(status.documentID, asset?.uploaded.assetId)
        XCTAssertEqual(status.fileName, asset?.original.name)
    }
    
    private func createAsset() -> ZMAsset {
        let (otrKey, sha) = (Data.randomEncryptionKey(), Data.zmRandomSHA256Key())
        let (assetId, token) = ("id", "token")
        let original = ZMAssetOriginal.original(withSize: 200, mimeType: "application/pdf", name: "PDF test")
        
        let assetBuilder = ZMAsset.builder()!
        let remoteBuilder = ZMAssetRemoteData.builder()!
        
        _ = remoteBuilder.setOtrKey(otrKey)
        _ = remoteBuilder.setSha256(sha)
        _ = remoteBuilder.setAssetId(assetId)
        _ = remoteBuilder.setAssetToken(token)
        
        assetBuilder.setUploaded(remoteBuilder)
        assetBuilder.setOriginal(original)
        let sut =  ZMGenericMessage.message(content: assetBuilder.build(), nonce: UUID.create())
        
        return sut.asset
    }
}

