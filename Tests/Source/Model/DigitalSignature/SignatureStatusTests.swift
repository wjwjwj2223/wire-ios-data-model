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
    
    private func createAsset() -> ZMAsset? {
        let imageMetaData = ZMAssetImageMetaData.imageMetaData(withWidth: 30, height: 40)
        let imageMetaDataBuilder = imageMetaData.toBuilder()!
        let original  = ZMAssetOriginal.original(withSize: 200, mimeType: "application/pdf", name: "PDF test", imageMetaData: imageMetaData)
        let remoteData = ZMAssetRemoteData.remoteData(withOTRKey: Data(), sha256: Data(), assetId: "id", assetToken: "token")
        let preview = ZMAssetPreview.preview(withSize: 200, mimeType: "application/pdf", remoteData: remoteData, imageMetadata: imageMetaDataBuilder.build())
        return ZMAsset.asset(withOriginal: original, preview: preview)
    }
}

