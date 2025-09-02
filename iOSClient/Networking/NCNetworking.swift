//
//  NCNetworking.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 23/10/19.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import OpenSSL
import NextcloudKit
import Alamofire
import Queuer
import SwiftUI

@objc protocol ClientCertificateDelegate {
    func onIncorrectPassword()
    func didAskForClientCertificate()
}

protocol NCTransferDelegate: AnyObject {
    var sceneIdentifier: String { get }
    func transferProgressDidUpdate(progress: Float,
                                   totalBytes: Int64,
                                   totalBytesExpected: Int64,
                                   fileName: String,
                                   serverUrl: String)

    func transferChange(status: String, metadata: tableMetadata, error: NKError)
    func transferChange(status: String, metadatasError: [tableMetadata: NKError])
    func transferReloadData(serverUrl: String?, status: Int?)
    func transferRequestData(serverUrl: String?)
    func transferCopy(metadata: tableMetadata, destination: String, error: NKError)
    func transferMove(metadata: tableMetadata, destination: String, error: NKError)
}

extension NCTransferDelegate {
    func transferProgressDidUpdate(progress: Float,
                                   totalBytes: Int64,
                                   totalBytesExpected: Int64,
                                   fileName: String,
                                   serverUrl: String) {}
    func transferChange(status: String, metadata: tableMetadata, error: NKError) {}
    func transferChange(status: String, metadatasError: [tableMetadata: NKError]) {}
    func transferReloadData(serverUrl: String?, status: Int?) {}
    func transferRequestData(serverUrl: String?) {}
    func transferCopy(metadata: tableMetadata, destination: String, error: NKError) {}
    func transferMove(metadata: tableMetadata, destination: String, error: NKError) {}
}

/// Actor-based delegate dispatcher using weak references.
actor NCTransferDelegateDispatcher {
    // Weak reference collection of delegates
    private var transferDelegates = NSHashTable<AnyObject>.weakObjects()

    /// Adds a delegate safely.
    func addDelegate(_ delegate: NCTransferDelegate) {
        transferDelegates.add(delegate)
    }

    /// Remove a delegate safely.
    func removeDelegate(_ delegate: NCTransferDelegate) {
        transferDelegates.remove(delegate)
    }

    /// Notifies all delegates.
    func notifyAllDelegates(_ block: (NCTransferDelegate) -> Void) {
        let delegatesCopy = transferDelegates.allObjects
        for delegate in delegatesCopy {
            if let delegate = delegate as? NCTransferDelegate {
                block(delegate)
            }
        }
    }

    func notifyAllDelegatesAsync(_ block: @escaping (NCTransferDelegate) async -> Void) async {
        let delegatesCopy = transferDelegates.allObjects
        for delegate in delegatesCopy {
            if let delegate = delegate as? NCTransferDelegate {
                await block(delegate)
            }
        }
    }

    /// Notifies the delegate for a specific scene.
    func notifyDelegate(forScene sceneIdentifier: String, _ block: (NCTransferDelegate) -> Void) {
        let delegatesCopy = transferDelegates.allObjects
        for delegate in delegatesCopy {
            if let delegate = delegate as? NCTransferDelegate,
               delegate.sceneIdentifier == sceneIdentifier {
                block(delegate)
            }
        }
    }

    /// Notifies matching and non-matching delegates for a specific scene.
    func notifyDelegates(forScene sceneIdentifier: String,
                         matching: (NCTransferDelegate) -> Void,
                         others: (NCTransferDelegate) -> Void) {
        let delegatesCopy = transferDelegates.allObjects
        for delegate in delegatesCopy {
            guard let delegate = delegate as? NCTransferDelegate else { continue }
            if delegate.sceneIdentifier == sceneIdentifier {
                matching(delegate)
            } else {
                others(delegate)
            }
        }
    }
}

/// A thread-safe registry for tracking in-flight `URLSessionTask` instances.
///
/// Each task is associated with a string identifier (`identifier`) that you define,
/// allowing you to check whether a request is already running, avoid duplicates,
/// and cancel all active tasks at once. The registry automatically removes
/// completed tasks via `cleanupCompleted()` to keep memory usage compact.
///
/// Typical use cases:
/// - Ensure only one task per identifier is active at a time.
/// - Query whether a specific request is still running (`isReading`).
/// - Forcefully stop a specific request (`cancel`).
/// - Forcefully stop all tasks when leaving a screen (`cancelAll`).
actor NetworkingTasks {
    private var active: [(identifier: String, task: URLSessionTask)] = []

    /// Returns whether there is an in-flight task for the given URL.
    ///
    /// A task is considered in-flight if its `state` is `.running` or `.suspended`.
    /// - Parameter identifier: The identifier to check.
    /// - Returns: `true` if a matching in-flight task exists; otherwise `false`.
    func isReading(identifier: String) -> Bool {
        // Drop finished/canceling tasks globally
        cleanup()

        return active.contains {
            $0.identifier == identifier && ($0.task.state == .running || $0.task.state == .suspended)
        }
    }

    /// Tracks a newly created `URLSessionTask` for the given identifier.
    ///
    /// If a running entry for the same identifier exists, it is removed before appending the new one.
    /// - Parameters:
    ///   - identifier: The identifier associated with the task.
    ///   - task: The `URLSessionTask` to track.
    func track(identifier: String, task: URLSessionTask) {
        // Drop finished/canceling tasks globally
        cleanup()

        active.removeAll {
            $0.identifier == identifier && $0.task.state == .running
        }
        active.append((identifier, task))
        nkLog(tag: NCGlobal.shared.logNetworkingTasks, emoji: .start, message: "Start task for identifier: \(identifier)", consoleOnly: true)
    }

    /// create a Identifier
    /// 
    func createIdentifier(account: String? = nil, path: String? = nil, name: String) -> String {
        if let account,
           let path {
            return account + "_" + path + "_" + name
        } else if let path {
            return path + "_" + name
        } else {
            return name
        }
    }

    /// Cancels and removes all tasks associated with the given id.
    ///
    /// - Parameter identifier: The identifier whose tasks should be canceled.
    func cancel(identifier: String) {
        // Drop finished/canceling tasks globally
        cleanup()

        for element in active where element.identifier == identifier {
            element.task.cancel()
            nkLog(tag: NCGlobal.shared.logNetworkingTasks, emoji: .cancel, message: "Cancel task for identifier: \(identifier)", consoleOnly: true)
        }
        active.removeAll {
            $0.identifier == identifier
        }
    }

    /// Cancels all tracked `URLSessionTask` and clears the registry.
    ///
    /// Call this when leaving the page/screen or when the operation must be forcefully stopped.
    func cancelAll() {
        active.forEach {
            $0.task.cancel()
            nkLog(tag: NCGlobal.shared.logNetworkingTasks, emoji: .cancel, message: "Cancel task with identifier: \($0.identifier)", consoleOnly: true)
        }
        active.removeAll()
    }

    /// Removes tasks that have completed from the registry.
    ///
    /// Useful to keep the in-memory list compact during long-running operations.
    func cleanup() {
        active.removeAll {
            $0.task.state == .completed || $0.task.state == .canceling
        }
    }
}

class NCNetworking: @unchecked Sendable, NextcloudKitDelegate {
    static let shared = NCNetworking()

    let networkingTasks = NetworkingTasks()

    let sessionDownload = NextcloudKit.shared.nkCommonInstance.identifierSessionDownload
    let sessionDownloadBackground = NextcloudKit.shared.nkCommonInstance.identifierSessionDownloadBackground
    let sessionDownloadBackgroundExt = NextcloudKit.shared.nkCommonInstance.identifierSessionDownloadBackgroundExt

    let sessionUpload = NextcloudKit.shared.nkCommonInstance.identifierSessionUpload
    let sessionUploadBackground = NextcloudKit.shared.nkCommonInstance.identifierSessionUploadBackground
    let sessionUploadBackgroundWWan = NextcloudKit.shared.nkCommonInstance.identifierSessionUploadBackgroundWWan
    let sessionUploadBackgroundExt = NextcloudKit.shared.nkCommonInstance.identifierSessionUploadBackgroundExt

    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let global = NCGlobal.shared
    let backgroundSession = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)

    var requestsUnifiedSearch: [DataRequest] = []
    var lastReachability: Bool = true
    var networkReachability: NKTypeReachability?
    weak var certificateDelegate: ClientCertificateDelegate?
    var tapHudStopDelete = false
    var controller: UIViewController?

    var isOffline: Bool {
        return networkReachability == NKTypeReachability.notReachable || networkReachability == NKTypeReachability.unknown
    }
    var isOnline: Bool {
        return networkReachability == NKTypeReachability.reachableEthernetOrWiFi || networkReachability == NKTypeReachability.reachableCellular
    }

    // Capabilities
    var capabilities = ThreadSafeDictionary<String, NKCapabilities.Capabilities>()

    let transferDispatcher = NCTransferDelegateDispatcher()

    // OPERATIONQUEUE
    let downloadThumbnailQueue = Queuer(name: "downloadThumbnailQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    let downloadThumbnailActivityQueue = Queuer(name: "downloadThumbnailActivityQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    let downloadThumbnailTrashQueue = Queuer(name: "downloadThumbnailTrashQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    let unifiedSearchQueue = Queuer(name: "unifiedSearchQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    let saveLivePhotoQueue = Queuer(name: "saveLivePhotoQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    let downloadAvatarQueue = Queuer(name: "downloadAvatarQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)

    // MARK: - init

    init() { }

    // MARK: - Communication Delegate

    func networkReachabilityObserver(_ typeReachability: NKTypeReachability) {
        if typeReachability == NKTypeReachability.reachableCellular || typeReachability == NKTypeReachability.reachableEthernetOrWiFi {
            lastReachability = true
        } else {
            if lastReachability {
                let error = NKError(errorCode: global.errorNetworkNotAvailable, errorDescription: "")
                NCContentPresenter().messageNotification("_network_not_available_", error: error, delay: global.dismissAfterSecond, type: NCContentPresenter.messageType.info)
            }
            lastReachability = false
        }
        networkReachability = typeReachability
    }

    func retrieveIdentityFromKeychain(label: String) -> SecIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        // swiftlint:disable force_cast
        return status == errSecSuccess ? (item as! SecIdentity) : nil
        // swiftlint:enable force_cast
    }

    func authenticationChallenge(_ session: URLSession,
                                 didReceive challenge: URLAuthenticationChallenge,
                                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            let label = "client_identity_\(challenge.protectionSpace.host):\(challenge.protectionSpace.port)"
            print(label)
            if let identity = retrieveIdentityFromKeychain(label: label) {
                    let credential = URLCredential(identity: identity, certificates: nil, persistence: .forSession)

                    challenge.sender?.use(credential, for: challenge)
                    completionHandler(.useCredential, credential)

                } else {
                    self.certificateDelegate?.didAskForClientCertificate()
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
        } else {
            self.checkTrustedChallenge(session, didReceive: challenge, completionHandler: completionHandler)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
#if !EXTENSION
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate, let completionHandler = appDelegate.backgroundSessionCompletionHandler {
            nkLog(debug: "Called urlSessionDidFinishEvents for Background URLSession")
            appDelegate.backgroundSessionCompletionHandler = nil
            completionHandler()
        }
#endif
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>) { }

    // MARK: - Pinning check

    public func checkTrustedChallenge(_ session: URLSession,
                                      didReceive challenge: URLAuthenticationChallenge,
                                      completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let protectionSpace = challenge.protectionSpace
        let directoryCertificate = utilityFileSystem.directoryCertificates
        let host = protectionSpace.host
        let certificateSavedPath = (directoryCertificate as NSString).appendingPathComponent("\(host).der")

        guard let trust = protectionSpace.serverTrust,
              let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let certificate = certificates.first else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Salvataggio asincrono → nessun rischio per il main thread
        DispatchQueue.global(qos: .utility).async {
            self.saveX509Certificate(certificate, host: host, directoryCertificate: directoryCertificate)

            let isServerTrusted = SecTrustEvaluateWithError(trust, nil)
            let certificateCopyData = SecCertificateCopyData(certificate)
            let data = CFDataGetBytePtr(certificateCopyData)
            let size = CFDataGetLength(certificateCopyData)
            let certificateData = Data(bytes: data!, count: size)

            let tmpPath = (directoryCertificate as NSString).appendingPathComponent("\(host).tmp")
            try? certificateData.write(to: URL(fileURLWithPath: tmpPath), options: .atomic)

            var isTrusted = false

            if isServerTrusted {
                isTrusted = true
            } else if let savedData = try? Data(contentsOf: URL(fileURLWithPath: certificateSavedPath)),
                      savedData == certificateData {
                isTrusted = true
            }

            DispatchQueue.main.async {
                if isTrusted {
                    completionHandler(.useCredential, URLCredential(trust: trust))
                } else {
    #if !EXTENSION
                    (UIApplication.shared.delegate as? AppDelegate)?.trustCertificateError(host: host)
    #endif
                    completionHandler(.performDefaultHandling, nil)
                }
            }
        }
    }

    func writeCertificate(host: String) {
        let directoryCertificate = utilityFileSystem.directoryCertificates
        let certificateAtPath = directoryCertificate + "/" + host + ".tmp"
        let certificateToPath = directoryCertificate + "/" + host + ".der"

        if !utilityFileSystem.copyFile(atPath: certificateAtPath, toPath: certificateToPath) {
            nkLog(error: "Write certificare error")
        }
    }

    func saveX509Certificate(_ certificate: SecCertificate, host: String, directoryCertificate: String) {
        let certNamePathTXT = directoryCertificate + "/" + host + ".txt"
        let data: CFData = SecCertificateCopyData(certificate)
        let mem = BIO_new_mem_buf(CFDataGetBytePtr(data), Int32(CFDataGetLength(data)))
        let x509cert = d2i_X509_bio(mem, nil)

        if x509cert == nil {
            nkLog(error: "OpenSSL couldn't parse X509 Certificate")
        } else {
            // save details
            if FileManager.default.fileExists(atPath: certNamePathTXT) {
                do {
                    try FileManager.default.removeItem(atPath: certNamePathTXT)
                } catch { }
            }
            let fileCertInfo = fopen(certNamePathTXT, "w")
            if fileCertInfo != nil {
                let output = BIO_new_fp(fileCertInfo, BIO_NOCLOSE)
                X509_print_ex(output, x509cert, UInt(XN_FLAG_COMPAT), UInt(X509_FLAG_COMPAT))
                BIO_free(output)
            }
            fclose(fileCertInfo)
            X509_free(x509cert)
        }

        BIO_free(mem)
    }
}
