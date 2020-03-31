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

// MARK: - SignatureObserver
@objc(ZMSignatureObserver)
public protocol SignatureObserver: NSObjectProtocol {
    func willReceiveSignatureURL()
    func didReceiveSignatureURL(_ url: URL)
    func signatureAvailable(_ signature: Data)
    func signatureInvalid(_ error: Error)
}

public extension NSNotification.Name {
    static let didReceiveDigitalSignature = Notification.Name("didReceiveDigitalSignature")
    static let didReceiveInvalidDigitalSignature = Notification.Name("didReceiveInvalidDigitalSignature")
    static let willSignDocument = Notification.Name("willSignDocument")
}

// MARK: - SignatureStatus
public enum PDFSigningState: Int {
    case initial
    case waitingForURL
    case waitingForSignature
    case signatureInvalid
    case finished
}

public final class SignatureStatus : NSObject {
    
    // MARK: - Private Property
    private(set) var asset: ZMAsset?
    private(set) var managedObjectContext: NSManagedObjectContext

    // MARK: - Public Property
    public var state: PDFSigningState = .initial
    public var documentID: String?
    public var fileName: String?
    public var encodedHash: String?

    // MARK: - Init
    public init(asset: ZMAsset?,
                managedObjectContext: NSManagedObjectContext) {
        self.asset = asset
        self.managedObjectContext = managedObjectContext
        
        documentID = asset?.preview.remote.assetId
        fileName = asset?.original.name.removingExtremeCombiningCharacters
        encodedHash = asset?.data()
            .zmSHA256Digest()
            .base64String()
    }

    // MARK: - Public Method
    public func signDocument() {
        guard encodedHash != nil else {
            return
        }
        state = .waitingForURL
        NotificationCenter.default.post(name: .willSignDocument, object: self)
        DigitalSignatureNotification(state: .consentURLPending)
            .post(in: managedObjectContext.notificationContext)
    }
    
    public func didReceiveURL(_ url: URL) {
        state = .waitingForSignature
        DigitalSignatureNotification(state: .consentURLReceived(url))
            .post(in: managedObjectContext.notificationContext)
    }
    
    public func didReceiveSignature(data: Data?) { //TODO: what type of the file?
        guard let _ = data else {
                state = .signatureInvalid
                NotificationInContext(name: .didReceiveInvalidDigitalSignature,
                                      context: managedObjectContext.notificationContext).post()
                return
        }
        state = .finished
        NotificationInContext(name: .didReceiveDigitalSignature,
                              context: managedObjectContext.notificationContext).post()
    }
    
    // MARK: - Observable
    public func addObserver(_ observer: SignatureObserver) -> Any {
        return NotificationInContext.addObserver(name: DigitalSignatureNotification.notificationName,
                                                 context: managedObjectContext.notificationContext,
                                                 queue: .main) { [weak observer] note in
            if let note = note.userInfo[DigitalSignatureNotification.userInfoKey] as? DigitalSignatureNotification  {
                switch note.state {
                    case .consentURLPending:
                        observer?.willReceiveSignatureURL()
                    case let .consentURLReceived(consentURL):
                        observer?.didReceiveSignatureURL(consentURL)
                }
            }
        }
    }
}

// MARK: - DigitalSignatureNotification
public class DigitalSignatureNotification: NSObject  {
    
    // MARK: - State
    public enum State {
        case consentURLPending
        case consentURLReceived(_ consentURL: URL)
    }
    
    // MARK: - Public Property
    public static let notificationName = Notification.Name("DigitalSignatureNotification")
    public static let userInfoKey = notificationName.rawValue
    
    public let state: State
    
    // MARK: - Init
    public init(state: State) {
        self.state = state
        super.init()
    }
    
    // MARK: - Public Method
    public func post(in context: NotificationContext) {
        NotificationInContext(name: DigitalSignatureNotification.notificationName,
                              context: context,
                              userInfo: [DigitalSignatureNotification.userInfoKey: self]).post()
    }
}
