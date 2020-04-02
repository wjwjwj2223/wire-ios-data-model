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
    func didFailSignature()
}

public extension NSNotification.Name {
    static let willSignDocument = Notification.Name("willSignDocument")
    static let willRetrieveSignature = Notification.Name("willRetrieveSignature")
}

// MARK: - SignatureStatus
public enum PDFSigningState: Int {
    case initial
    case waitingForConsentURL
    case waitingForCodeVerification
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
        state = .waitingForConsentURL
        NotificationCenter.default.post(name: .willSignDocument, object: self)
        DigitalSignatureNotification(state: .consentURLPending)
            .post(in: managedObjectContext.notificationContext)
    }
    
    public func retrieveSignature() {
        state = .waitingForSignature
        NotificationCenter.default.post(name: .willRetrieveSignature, object: nil)
    }
    
    public func didReceiveConsentURL(_ url: URL) {
        state = .waitingForCodeVerification
        DigitalSignatureNotification(state: .consentURLReceived(url))
            .post(in: managedObjectContext.notificationContext)
    }
    
    public func didReceiveSignature(data: Data?) { //TODO: what type of the file?
        guard let _ = data else {
                state = .signatureInvalid
                DigitalSignatureNotification(state: .signatureInvalid)
                    .post(in: managedObjectContext.notificationContext)
                return
        }
        state = .finished
        DigitalSignatureNotification(state: .digitalSignatureReceived)
            .post(in: managedObjectContext.notificationContext)
    }
    
    public func didReceiveError() {
        state = .signatureInvalid
        DigitalSignatureNotification(state: .signatureInvalid)
            .post(in: managedObjectContext.notificationContext)
    }
    
    public func store() {
        managedObjectContext.signatureStatus = self
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
                    case .signatureInvalid:
                        observer?.didFailSignature()
                    case .digitalSignatureReceived: // TO DO: Managege when we got the real data
                        break
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
        case signatureInvalid
        case digitalSignatureReceived
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

// MARK: - NSManagedObjectContext
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
