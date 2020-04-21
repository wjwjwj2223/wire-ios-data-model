//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

//extension ZMGenericMessage {
//    
//    @objc
//    func hashOfContent(with timestamp: Date) -> Data? {
//        guard let content = content as? BigEndianDataConvertible else {
//            return nil
//        }
//        
//        return content.hashWithTimestamp(timestamp: timestamp.timeIntervalSince1970)
//    }
//    
//}
//
//extension ZMMessageEdit: BigEndianDataConvertible {
//    
//    var asBigEndianData: Data {
//        return text?.asBigEndianData ?? Data()
//    }
//    
//}
//
//extension ZMText: BigEndianDataConvertible {
//    
//    var asBigEndianData: Data {
//        return content.asBigEndianData
//    }
//    
//}
//
//extension ZMLocation: BigEndianDataConvertible {
//    
//    var asBigEndianData: Data {
//        var data = latitude.times1000.asBigEndianData
//        data.append(longitude.times1000.asBigEndianData)
//        return data
//    }
//    
//}
//
//extension ZMAsset: BigEndianDataConvertible {
//    
//    var asBigEndianData: Data {
//        return uploaded?.assetId.asBigEndianData ?? Data()
//    }
//}
//
//fileprivate extension Float {
//    
//    var times1000: Int {
//        return Int(roundf(self * 1000.0))
//    }
//}
