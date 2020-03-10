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

import Foundation

public extension WireProtos.Asset.Original {
    
    /// Returns the normalized loudness as floats between 0 and 1
    var normalizedLoudnessLevels : [Float] {
        
        guard self.audio.hasNormalizedLoudness else { return [] }
        guard !self.audio.normalizedLoudness.isEmpty else { return [] }
        
        let data = self.audio.normalizedLoudness 
        let offsets = 0..<data.count
        return offsets.map { offset -> UInt8 in
            var number : UInt8 = 0
            data.copyBytes(to: &number, from: (0 + offset)..<(MemoryLayout<UInt8>.size+offset))
            return number
            }
            .map { Float(Float($0)/255.0) }
    }
}
