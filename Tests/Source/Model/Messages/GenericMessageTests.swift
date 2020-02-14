//
//  GenericMessageTests.swift
//  WireDataModelTests
//
//  Created by David Henner on 14.02.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation
@testable import WireDataModel

class GenericMessageTests: XCTestCase {
    func testThatItChecksTheCommonMessageTypeAsKnownMessage() {
        let generators: [()->(GenericMessage)] = [
            { return GenericMessage(content: Text(content: "hello")) },
            { return GenericMessage(content: Knock()) },
            { return GenericMessage(content: LastRead(conversationID: UUID.create(), lastReadTimestamp: Date())) },
            {
                let sha256 = Data(base64Encoded: "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=")!
                let otrKey = Data(base64Encoded: "4H1nD6bG2sCxC/tZBnIG7avLYhkCsSfv0ATNqnfug7w=")!
                return GenericMessage(content: External(withOTRKey: otrKey, sha256: sha256))
            },
            { return GenericMessage(content: Calling(content: "Calling")) },
            { return GenericMessage(content: WireProtos.Asset(imageSize: .zero, mimeType: "image/jpeg", size: 0)) },
            { return GenericMessage(content: WireProtos.Reaction(emoji: "test", messageID: UUID.create())) }
        ]
        
        generators.forEach { generator in
            let message = generator()
            XCTAssertTrue(message.knownMessage)
        }
    }
}
