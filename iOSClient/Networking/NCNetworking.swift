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
import Photos
import Queuer
import JGProgressHUD
import RealmSwift

@objc public protocol NCNetworkingDelegate {
    @objc optional func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Int64, fileNameLocalPath: String?, task: URLSessionTask, error: NKError)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, fileNameLocalPath: String?, task: URLSessionTask, error: NKError)
}

#if EXTENSION_FILE_PROVIDER_EXTENSION || EXTENSION_WIDGET
@objc protocol uploadE2EEDelegate: AnyObject { }
#endif

@objcMembers
class NCNetworking: NSObject, NKCommonDelegate {
    public static let shared: NCNetworking = {
        let instance = NCNetworking()
        return instance
    }()

    public struct TransferInForegorund {
        var ocId: String
        var progress: Float
    }

    struct FileNameServerUrl: Hashable {
        var fileName: String
        var serverUrl: String

    }

    weak var delegate: NCNetworkingDelegate?
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    var lastReachability: Bool = true
    var networkReachability: NKCommon.TypeReachability?
    let downloadRequest = ThreadSafeDictionary<String, DownloadRequest>()
    let uploadRequest = ThreadSafeDictionary<String, UploadRequest>()
    let uploadMetadataInBackground = ThreadSafeDictionary<FileNameServerUrl, tableMetadata>()
    let downloadMetadataInBackground = ThreadSafeDictionary<FileNameServerUrl, tableMetadata>()
    var transferInForegorund: TransferInForegorund?

    lazy var nkBackground: NKBackground = {
        let nckb = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)
        return nckb
    }()

    public let sessionMaximumConnectionsPerHost = 5
    public let sessionDownloadBackground: String = "com.nextcloud.session.download.background"
    public let sessionUploadBackground: String = "com.nextcloud.session.upload.background"
    public let sessionUploadBackgroundWWan: String = "com.nextcloud.session.upload.backgroundWWan"
    public let sessionUploadBackgroundExtension: String = "com.nextcloud.session.upload.extension"

    public lazy var sessionManagerDownloadBackground: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionDownloadBackground)
        configuration.allowsCellularAccess = true
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = sessionMaximumConnectionsPerHost
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: nkBackground, delegateQueue: OperationQueue.main)
        return session
    }()

    public lazy var sessionManagerUploadBackground: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionUploadBackground)
        configuration.allowsCellularAccess = true
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = sessionMaximumConnectionsPerHost
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: nkBackground, delegateQueue: OperationQueue.main)
        return session
    }()

    public lazy var sessionManagerUploadBackgroundWWan: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionUploadBackgroundWWan)
        configuration.allowsCellularAccess = false
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = sessionMaximumConnectionsPerHost
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: nkBackground, delegateQueue: OperationQueue.main)
        return session
    }()

#if EXTENSION
    public lazy var sessionManagerUploadBackgroundExtension: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionUploadBackgroundExtension)
        configuration.allowsCellularAccess = true
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = sessionMaximumConnectionsPerHost
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        configuration.sharedContainerIdentifier = NCBrandOptions.shared.capabilitiesGroups
        let session = URLSession(configuration: configuration, delegate: nkBackground, delegateQueue: OperationQueue.main)
        return session
    }()
#endif

    // REQUESTS
    var requestsUnifiedSearch: [DataRequest] = []

    // OPERATIONQUEUE
    let downloadThumbnailQueue = Queuer(name: "downloadThumbnailQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    let downloadThumbnailActivityQueue = Queuer(name: "downloadThumbnailActivityQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    let unifiedSearchQueue = Queuer(name: "unifiedSearchQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    let saveLivePhotoQueue = Queuer(name: "saveLivePhotoQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    let downloadQueue = Queuer(name: "downloadQueue", maxConcurrentOperationCount: NCBrandOptions.shared.maxConcurrentOperationDownload, qualityOfService: .default)
    let downloadAvatarQueue = Queuer(name: "downloadAvatarQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    let convertLivePhotoQueue = Queuer(name: "convertLivePhotoQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)

    // MARK: - init

    override init() {
        super.init()

#if EXTENSION
        print("Start Background Upload Extension: ", sessionUploadBackgroundExtension)
#else
        print("Start Background Download: ", sessionManagerDownloadBackground)
        print("Start Background Upload: ", sessionManagerUploadBackground)
        print("Start Background Upload WWan: ", sessionManagerUploadBackgroundWWan)
#endif
    }

    // MARK: - Communication Delegate

    func networkReachabilityObserver(_ typeReachability: NKCommon.TypeReachability) {

        if typeReachability == NKCommon.TypeReachability.reachableCellular || typeReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
            if !lastReachability {
#if !EXTENSION
                NCService().startRequestServicesServer()
#endif
            }
            lastReachability = true
        } else {
            if lastReachability {
                let error = NKError(errorCode: NCGlobal.shared.errorNetworkNotAvailable, errorDescription: "")
                NCContentPresenter().messageNotification("_network_not_available_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info)
            }
            lastReachability = false
        }
        networkReachability = typeReachability
    }

    func authenticationChallenge(_ session: URLSession,
                                 didReceive challenge: URLAuthenticationChallenge,
                                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        DispatchQueue.global().async {
            self.checkTrustedChallenge(session, didReceive: challenge, completionHandler: completionHandler)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {

#if !EXTENSION
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate, let completionHandler = appDelegate.backgroundSessionCompletionHandler {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Called urlSessionDidFinishEvents for Background URLSession")
            appDelegate.backgroundSessionCompletionHandler = nil
            completionHandler()
        }
#endif
    }

    // MARK: - Queue

    func cancelAllQueue() {

        downloadQueue.cancelAll()
        downloadThumbnailQueue.cancelAll()
        downloadThumbnailActivityQueue.cancelAll()
        downloadAvatarQueue.cancelAll()
        unifiedSearchQueue.cancelAll()
        saveLivePhotoQueue.cancelAll()
        convertLivePhotoQueue.cancelAll()
    }

    // MARK: - Pinning check

    public func checkTrustedChallenge(_ session: URLSession,
                                      didReceive challenge: URLAuthenticationChallenge,
                                      completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        let protectionSpace: URLProtectionSpace = challenge.protectionSpace
        let directoryCertificate = utilityFileSystem.directoryCertificates
        let host = challenge.protectionSpace.host
        let certificateSavedPath = directoryCertificate + "/" + host + ".der"
        var isTrusted: Bool

        if let serverTrust: SecTrust = protectionSpace.serverTrust, let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {

            // extarct certificate txt
            saveX509Certificate(certificate, host: host, directoryCertificate: directoryCertificate)

            let isServerTrusted = SecTrustEvaluateWithError(serverTrust, nil)
            let certificateCopyData = SecCertificateCopyData(certificate)
            let data = CFDataGetBytePtr(certificateCopyData)
            let size = CFDataGetLength(certificateCopyData)
            let certificateData = NSData(bytes: data, length: size)

            certificateData.write(toFile: directoryCertificate + "/" + host + ".tmp", atomically: true)

            if isServerTrusted {
                isTrusted = true
            } else if let certificateDataSaved = NSData(contentsOfFile: certificateSavedPath), certificateData.isEqual(to: certificateDataSaved as Data) {
                isTrusted = true
            } else {
                isTrusted = false
            }
        } else {
            isTrusted = false
        }

        if isTrusted {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
        } else {
#if !EXTENSION
            DispatchQueue.main.async { (UIApplication.shared.delegate as? AppDelegate)?.trustCertificateError(host: host) }
#endif
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }

    func writeCertificate(host: String) {

        let directoryCertificate = utilityFileSystem.directoryCertificates
        let certificateAtPath = directoryCertificate + "/" + host + ".tmp"
        let certificateToPath = directoryCertificate + "/" + host + ".der"

        if !utilityFileSystem.copyFile(atPath: certificateAtPath, toPath: certificateToPath) {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Write certificare error")
        }
    }

    func saveX509Certificate(_ certificate: SecCertificate, host: String, directoryCertificate: String) {

        let certNamePathTXT = directoryCertificate + "/" + host + ".txt"
        let data: CFData = SecCertificateCopyData(certificate)
        let mem = BIO_new_mem_buf(CFDataGetBytePtr(data), Int32(CFDataGetLength(data)))
        let x509cert = d2i_X509_bio(mem, nil)

        if x509cert == nil {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] OpenSSL couldn't parse X509 Certificate")
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

    func checkPushNotificationServerProxyCertificateUntrusted(viewController: UIViewController?,
                                                              completion: @escaping (_ error: NKError) -> Void) {

        guard let host = URL(string: NCBrandOptions.shared.pushNotificationServerProxy)?.host else { return }

        NextcloudKit.shared.checkServer(serverUrl: NCBrandOptions.shared.pushNotificationServerProxy) { error in
            guard error == .success else {
                completion(.success)
                return
            }

            if error == .success {
                NCNetworking.shared.writeCertificate(host: host)
                completion(error)
            } else if error.errorCode == NSURLErrorServerCertificateUntrusted {
                let alertController = UIAlertController(title: NSLocalizedString("_ssl_certificate_untrusted_", comment: ""), message: NSLocalizedString("_connect_server_anyway_", comment: ""), preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { _ in
                    NCNetworking.shared.writeCertificate(host: host)
                    completion(.success)
                }))
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { _ in
                    completion(error)
                }))
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_certificate_details_", comment: ""), style: .default, handler: { _ in
                    if let navigationController = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                       let vcCertificateDetails = navigationController.topViewController as? NCViewCertificateDetails {
                        vcCertificateDetails.host = host
                        viewController?.present(navigationController, animated: true)
                    }
                }))
                viewController?.present(alertController, animated: true)
            }
        }
    }

    // MARK: - Live Photo

    func uploadLivePhoto(metadata: tableMetadata, userInfo aUserInfo: [AnyHashable: Any]) {

        guard let metadata1 = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND urlBase == %@ AND path == %@ AND fileName == %@", metadata.account, metadata.urlBase, metadata.path, metadata.livePhotoFile)) else {
            metadata.livePhotoFile = ""
            NCManageDatabase.shared.addMetadata(metadata)
            return NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedLivePhoto),
                                                   object: nil,
                                                   userInfo: aUserInfo)
        }
        if metadata1.status != NCGlobal.shared.metadataStatusNormal { return }

        Task {
            let serverUrlfileNamePath = metadata.urlBase + metadata.path + metadata.fileName
            var livePhotoFile = metadata1.fileId
            let results = await NextcloudKit.shared.setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath, livePhotoFile: livePhotoFile)
            if results.error == .success {
                NCManageDatabase.shared.setMetadataLivePhotoByServer(account: metadata.account, ocId: metadata.ocId, livePhotoFile: livePhotoFile)
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Uplod set LivePhoto with error \(results.error.errorCode)")
            }

            let serverUrlfileNamePath1 = metadata1.urlBase + metadata1.path + metadata1.fileName
            livePhotoFile = metadata.fileId
            let results1 = await NextcloudKit.shared.setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath1, livePhotoFile: livePhotoFile)
            if results1.error == .success {
                NCManageDatabase.shared.setMetadataLivePhotoByServer(account: metadata1.account, ocId: metadata1.ocId, livePhotoFile: livePhotoFile)
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Upload set LivePhoto with error \(results.error.errorCode)")
            }
            if results.error == .success, results1.error == .success {
                NextcloudKit.shared.nkCommonInstance.writeLog("[SUCCESS] Upload set LivePhoto for files " + (metadata.fileName as NSString).deletingPathExtension)

            }
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedLivePhoto),
                                            object: nil,
                                            userInfo: aUserInfo)
        }
    }

    func convertLivePhoto(metadata: tableMetadata) {

        guard metadata.status == NCGlobal.shared.metadataStatusNormal else { return }

        let account = metadata.account
        let livePhotoFile = metadata.livePhotoFile
        let serverUrlfileNamePath = metadata.urlBase + metadata.path + metadata.fileName
        let ocId = metadata.ocId

        DispatchQueue.global().async {
            if let result = NCManageDatabase.shared.getResultMetadata(predicate: NSPredicate(format: "account == '\(account)' AND status == \(NCGlobal.shared.metadataStatusNormal) AND (fileName == '\(livePhotoFile)' || fileId == '\(livePhotoFile)')")) {
                if livePhotoFile == result.fileId { return }
                for case let operation as NCOperationConvertLivePhoto in self.convertLivePhotoQueue.operations where operation.serverUrlfileNamePath == serverUrlfileNamePath { continue }
                self.convertLivePhotoQueue.addOperation(NCOperationConvertLivePhoto(serverUrlfileNamePath: serverUrlfileNamePath, livePhotoFile: result.fileId, account: account, ocId: ocId))
            }
        }
    }

    // MARK: - Cancel (Download Upload)

    // sessionIdentifierDownload: String = "com.nextcloud.nextcloudkit.session.download"
    // sessionIdentifierUpload: String = "com.nextcloud.nextcloudkit.session.upload"

    // sessionUploadBackground: String = "com.nextcloud.session.upload.background"
    // sessionUploadBackgroundWWan: String = "com.nextcloud.session.upload.backgroundWWan"
    // sessionUploadBackgroundExtension: String = "com.nextcloud.session.upload.extension"

    func cancelDataTask() {

        let sessionManager = NextcloudKit.shared.sessionManager
        sessionManager.session.getTasksWithCompletionHandler { dataTasks, _, _ in
            dataTasks.forEach {
                $0.cancel()
            }
        }
    }

    

    func cancelUploadTasks() {

        uploadRequest.removeAll()
        let sessionManager = NextcloudKit.shared.sessionManager
        sessionManager.session.getTasksWithCompletionHandler { _, uploadTasks, _ in
            uploadTasks.forEach {
                $0.cancel()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status > 0 AND session == %@", NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload)) {
                NCManageDatabase.shared.deleteMetadata(results: results)
            }
        }
    }

    func cancelUploadBackgroundTask(withNotification: Bool) {

        Task {
            let tasksBackground = await NCNetworking.shared.sessionManagerUploadBackground.tasks
            for task in tasksBackground.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                task.cancel()
            }
            let tasksBackgroundWWan = await NCNetworking.shared.sessionManagerUploadBackgroundWWan.tasks
            for task in tasksBackgroundWWan.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                task.cancel()
            }

            if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status > 0 AND (session == %@ || session == %@)", NCNetworking.shared.sessionUploadBackground, NCNetworking.shared.sessionUploadBackgroundWWan)) {
                NCManageDatabase.shared.deleteMetadata(results: results)
            }
            if withNotification {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
            }
        }
    }

    func cancel(metadata: tableMetadata) async {

        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
        utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))

        // No session found
        if metadata.session.isEmpty {
            uploadRequest.removeValue(forKey: fileNameLocalPath)
            downloadRequest.removeValue(forKey: fileNameLocalPath)
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
            return
        }

        // DOWNLOAD
        if metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload {
            if let request = downloadRequest[fileNameLocalPath] {
                request.cancel()
            } else if let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) {
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           session: "",
                                                           sessionError: "",
                                                           selector: "",
                                                           status: NCGlobal.shared.metadataStatusNormal,
                                                           errorCode: 0)
                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile),
                                                object: nil,
                                                userInfo: ["ocId": metadata.ocId,
                                                           "serverUrl": metadata.serverUrl,
                                                           "account": metadata.account])
            }
            return
        }

        // UPLOAD FOREGROUND
        if metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload {
            if let request = uploadRequest[fileNameLocalPath] {
                request.cancel()
                uploadRequest.removeValue(forKey: fileNameLocalPath)
            }
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile),
                                            object: nil,
                                            userInfo: ["ocId": metadata.ocId,
                                                       "serverUrl": metadata.serverUrl,
                                                       "account": metadata.account])
            return
        }

        // UPLOAD BACKGROUND
        var session: URLSession?
        if metadata.session == NCNetworking.shared.sessionUploadBackground {
            session = NCNetworking.shared.sessionManagerUploadBackground
        } else if metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan {
            session = NCNetworking.shared.sessionManagerUploadBackgroundWWan
        }
        if let tasks = await session?.tasks {
            for task in tasks.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                if task.taskIdentifier == metadata.sessionTaskIdentifier {
                    task.cancel()
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile),
                                                    object: nil,
                                                    userInfo: ["ocId": metadata.ocId,
                                                               "serverUrl": metadata.serverUrl,
                                                               "account": metadata.account])
                }
            }
        }
    }

    // MARK: - Synchronization ServerUrl

    func synchronization(account: String,
                         serverUrl: String,
                         selector: String,
                         completion: @escaping () -> Void = {}) {

        let startDate = Date()

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl,
                                             depth: "infinity",
                                             showHiddenFiles: NCKeychain().showHiddenFiles,
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, files, _, error in

            if error == .success {
                NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: true) { _, _, metadatas in
                    for metadata in metadatas {
                        if metadata.directory {
                            NCManageDatabase.shared.addMetadata(metadata)
                        } else if selector == NCGlobal.shared.selectorSynchronizationOffline, metadata.isSynchronizable {
                            NCManageDatabase.shared.setMetadataSessionInWaitDownload(ocId: metadata.ocId,
                                                                                     session: NCNetworking.shared.sessionDownloadBackground,
                                                                                     selector: selector,
                                                                                     addMetadata: metadata)
                        }

                    }
                    let diffDate = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
                    NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Synchronization " + serverUrl + " in \(diffDate)")
                    completion()
                }
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Synchronization " + serverUrl + ", \(error.description)")
                completion()
            }
        }
    }

    func synchronization(account: String, serverUrl: String, selector: String) async {

        await withUnsafeContinuation({ continuation in
            synchronization(account: account, serverUrl: serverUrl, selector: selector) {
                continuation.resume(returning: ())
            }
        })
    }

    
    
    

    // MARK: - Lock Files

    func lockUnlockFile(_ metadata: tableMetadata, shoulLock: Bool) {

        NextcloudKit.shared.lockUnlockFile(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName, shouldLock: shoulLock) { _, error in
            // 0: lock was successful; 412: lock did not change, no error, refresh
            guard error == .success || error.errorCode == NCGlobal.shared.errorPreconditionFailed else {
                let error = NKError(errorCode: error.errorCode, errorDescription: "_files_lock_error_")
                NCContentPresenter().messageNotification(metadata.fileName, error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                return
            }
            NCNetworking.shared.readFile(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName) { _, metadata, error in
                guard error == .success, let metadata = metadata else { return }
                NCManageDatabase.shared.addMetadata(metadata)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
            }
        }
    }

    

    // MARK: - Direct Download

    func getVideoUrl(metadata: tableMetadata,
                     completition: @escaping (_ url: URL?, _ autoplay: Bool, _ error: NKError) -> Void) {

        if !metadata.url.isEmpty {
            if metadata.url.hasPrefix("/") {
                completition(URL(fileURLWithPath: metadata.url), true, .success)
            } else {
                completition(URL(string: metadata.url), true, .success)
            }
        } else if utilityFileSystem.fileProviderStorageExists(metadata) {
            completition(URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)), false, .success)
        } else {
            NextcloudKit.shared.getDirectDownload(fileId: metadata.fileId) { _, url, _, error in
                if error == .success && url != nil {
                    if let url = URL(string: url!) {
                        completition(url, false, error)
                    } else {
                        completition(nil, false, error)
                    }
                } else {
                    completition(nil, false, error)
                }
            }
        }
    }

    // MARK: - [NextcloudKit wrapper] convert completion handlers into async functions

    func getPreview(url: URL,
                    options: NKRequestOptions = NKRequestOptions()) async -> (account: String, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getPreview(url: url, options: options) { account, data, error in
                continuation.resume(returning: (account: account, data: data, error: error))
            }
        })
    }

    func downloadPreview(fileNamePathOrFileId: String,
                         fileNamePreviewLocalPath: String,
                         widthPreview: Int,
                         heightPreview: Int,
                         fileNameIconLocalPath: String? = nil,
                         sizeIcon: Int = 0,
                         etag: String? = nil,
                         endpointTrashbin: Bool = false,
                         useInternalEndpoint: Bool = true,
                         options: NKRequestOptions = NKRequestOptions()) async -> (account: String, imagePreview: UIImage?, imageIcon: UIImage?, imageOriginal: UIImage?, etag: String?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.downloadPreview(fileNamePathOrFileId: fileNamePathOrFileId, fileNamePreviewLocalPath: fileNamePreviewLocalPath, widthPreview: widthPreview, heightPreview: heightPreview, fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: sizeIcon, etag: etag, options: options) { account, imagePreview, imageIcon, imageOriginal, etag, error in
                continuation.resume(returning: (account: account, imagePreview: imagePreview, imageIcon: imageIcon, imageOriginal: imageOriginal, etag: etag, error: error))
            }
        })
    }
}

extension Array where Element == URLQueryItem {
    subscript(name: String) -> URLQueryItem? {
        first(where: { $0.name == name })
    }
}

// MARK: -


class NCOperationConvertLivePhoto: ConcurrentOperation {

    var serverUrlfileNamePath, livePhotoFile, account, ocId: String

    init(serverUrlfileNamePath: String, livePhotoFile: String, account: String, ocId: String) {
        self.serverUrlfileNamePath = serverUrlfileNamePath
        self.livePhotoFile = livePhotoFile
        self.account = account
        self.ocId = ocId
    }

    override func start() {

        guard !isCancelled else { return self.finish() }
        NextcloudKit.shared.setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath, livePhotoFile: livePhotoFile, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, error in
            if error == .success {
                NCManageDatabase.shared.setMetadataLivePhotoByServer(account: self.account, ocId: self.ocId, livePhotoFile: self.livePhotoFile)
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Convert LivePhoto with error \(error.errorCode)")
            }
            self.finish()
            if NCNetworking.shared.convertLivePhotoQueue.operationCount == 0 {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, second: 0.1)
            }
        }
    }
}

class NCOperationDownloadAvatar: ConcurrentOperation {

    var user: String
    var fileName: String
    var etag: String?
    var fileNameLocalPath: String
    var cell: NCCellProtocol!
    var view: UIView?
    var cellImageView: UIImageView?

    init(user: String, fileName: String, fileNameLocalPath: String, cell: NCCellProtocol, view: UIView?, cellImageView: UIImageView?) {
        self.user = user
        self.fileName = fileName
        self.fileNameLocalPath = fileNameLocalPath
        self.cell = cell
        self.view = view
        self.etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag
        self.cellImageView = cellImageView
    }

    override func start() {

        guard !isCancelled else { return self.finish() }

        NextcloudKit.shared.downloadAvatar(user: user,
                                           fileNameLocalPath: fileNameLocalPath,
                                           sizeImage: NCGlobal.shared.avatarSize,
                                           avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                                           etag: self.etag,
                                           options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, imageAvatar, _, etag, error in

            if error == .success, let imageAvatar = imageAvatar, let etag = etag {
                NCManageDatabase.shared.addAvatar(fileName: self.fileName, etag: etag)
                DispatchQueue.main.async {
                    if self.user == self.cell.fileUser, let avatarImageView = self.cellImageView {
                        UIView.transition(with: avatarImageView,
                                          duration: 0.75,
                                          options: .transitionCrossDissolve,
                                          animations: { avatarImageView.image = imageAvatar },
                                          completion: nil)
                    } else {
                        if self.view is UICollectionView {
                            (self.view as? UICollectionView)?.reloadData()
                        } else if self.view is UITableView {
                            (self.view as? UITableView)?.reloadData()
                        }
                    }
                }
            } else if error.errorCode == NCGlobal.shared.errorNotModified {
                NCManageDatabase.shared.setAvatarLoaded(fileName: self.fileName)
            }
            self.finish()
        }
    }
}
