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

extension String {
    
    static func randomChar() -> UnicodeScalar {
        let string = "abcdefghijklmnopqrstuvxyz"
        let chars = Array(string.unicodeScalars)
        let random = Int(arc4random_uniform(UInt32(chars.count)))
        return chars[random]
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


public extension ZMGenericMessage {

    public func obfuscatedMessage() -> ZMGenericMessage? {
        if let someText = textData {
            if let content = someText.content {
                let obfuscatedContent = content.obfuscated()
                return ZMGenericMessage.message(text: obfuscatedContent, nonce: messageId)
            }
        }
        return nil
    }
}
