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

private let SignatureStatusKey = "SignatureStatus"

extension NSManagedObjectContext {
    
    @objc public var signatureStatus: SignatureStatus? {
        get {
            return self.userInfo[SignatureStatusKey] as? SignatureStatus
        }
        set {
            self.userInfo[SignatureStatusKey] = newValue
        }
    }
}

public extension NSNotification.Name {
    static let didReceiveURLForSigningDocument = Notification.Name("DidReceiveURLForSigningDocument")
    static let didReceiveDigitalSignature = Notification.Name("DidReceiveDigitalSignature")
    static let didReceiveInvalidDigitalSignature = Notification.Name("DidReceiveInvalidDigitalSignature")
}

public enum PDFSigningState: Int {
    case initial
//    case hashing
    case waitingForURL
    case waitingForSignature
    case signatureInvalid
    case finished
}

public final class SignatureStatus : NSObject {
    private(set) var documentHash: String?
    private(set) var asset: Asset?
    private(set) var managedObjectContext: NSManagedObjectContext?

    public var state: PDFSigningState = .initial

    public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    public func signDocument(asset: Asset?) {
        self.asset = asset
        state = .waitingForURL
        NotificationCenter.default.post(name: Notification.Name(rawValue: "Test1"), object: nil)//"RequestsAvailableNotification"
    }
    
    func didReceiveURL(_ url: URL) {
        guard let moc = self.managedObjectContext else { return }
        state = .waitingForSignature
        NotificationInContext(name: .didReceiveURLForSigningDocument,
                              context: moc.notificationContext).post()
    }
    
    func didReceiveSignature(data: Data?) { //FIX ME: what type of the file?
        guard let moc = self.managedObjectContext else { return }
        guard let _ = data else {
                state = .signatureInvalid
                NotificationInContext(name: .didReceiveInvalidDigitalSignature,
                                      context: moc.notificationContext).post()
                return
        }
        state = .finished
        NotificationInContext(name: .didReceiveDigitalSignature,
                              context: moc.notificationContext).post()
    }
}
