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

#if EXTENSION_FILE_PROVIDER_EXTENSION || EXTENSION_WIDGET
@objc protocol uploadE2EEDelegate: AnyObject { }
#endif

@objc protocol NCNetworkingDelegate {
    func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: Date?, dateLastModified: Date?, length: Int64, task: URLSessionTask, error: NKError)
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: Date?, size: Int64, task: URLSessionTask, error: NKError)
}

@objc protocol ClientCertificateDelegate {
    func onIncorrectPassword()
    func didAskForClientCertificate()
}

@objcMembers
class NCNetworking: NSObject, NextcloudKitDelegate {
    public static let shared: NCNetworking = {
        let instance = NCNetworking()
        NotificationCenter.default.addObserver(instance, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        return instance
    }()

    struct FileNameServerUrl: Hashable {
        var fileName: String
        var serverUrl: String

    }

    let sessionDownload = NextcloudKit.shared.nkCommonInstance.identifierSessionDownload
    let sessionDownloadBackground = NextcloudKit.shared.nkCommonInstance.identifierSessionDownloadBackground
    let sessionUpload = NextcloudKit.shared.nkCommonInstance.identifierSessionUpload
    let sessionUploadBackground = NextcloudKit.shared.nkCommonInstance.identifierSessionUploadBackground
    let sessionUploadBackgroundWWan = NextcloudKit.shared.nkCommonInstance.identifierSessionUploadBackgroundWWan
    let sessionUploadBackgroundExt = NextcloudKit.shared.nkCommonInstance.identifierSessionUploadBackgroundExt

    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    var requestsUnifiedSearch: [DataRequest] = []
    var lastReachability: Bool = true
    var networkReachability: NKCommon.TypeReachability?
    weak var delegate: NCNetworkingDelegate?
    weak var certificateDelegate: ClientCertificateDelegate?
    var p12Data: Data?
    var p12Password: String?
    lazy var nkBackground: NKBackground = {
        let nckb = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)
        return nckb
    }()

    // OPERATIONQUEUE
    let downloadThumbnailQueue = Queuer(name: "downloadThumbnailQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    let downloadThumbnailActivityQueue = Queuer(name: "downloadThumbnailActivityQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    let downloadThumbnailTrashQueue = Queuer(name: "downloadThumbnailTrashQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    let unifiedSearchQueue = Queuer(name: "unifiedSearchQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    let saveLivePhotoQueue = Queuer(name: "saveLivePhotoQueue", maxConcurrentOperationCount: 1, qualityOfService: .default)
    let downloadQueue = Queuer(name: "downloadQueue", maxConcurrentOperationCount: NCBrandOptions.shared.maxConcurrentOperationDownload, qualityOfService: .default)
    let downloadAvatarQueue = Queuer(name: "downloadAvatarQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    let convertLivePhotoQueue = Queuer(name: "convertLivePhotoQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)

    // MARK: - init

    override init() {
        super.init()

        if let account = NCManageDatabase.shared.getActiveTableAccount()?.account {
            getActiveAccountCertificate(account: account)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil, queue: nil) { notification in
            if let userInfo = notification.userInfo {
                if let account = userInfo["account"] as? String {
                    self.getActiveAccountCertificate(account: account)
                }
            }
        }
    }

    // MARK: - NotificationCenter

    func applicationDidEnterBackground() {
        NCTransferProgress.shared.clearAllCountError()
    }

    // MARK: - Communication Delegate

    func networkReachabilityObserver(_ typeReachability: NKCommon.TypeReachability) {
        if typeReachability == NKCommon.TypeReachability.reachableCellular || typeReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
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
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            if let p12Data = self.p12Data,
               let cert = (p12Data, self.p12Password) as? UserCertificate,
               let pkcs12 = try? PKCS12(pkcs12Data: cert.data, password: cert.password, onIncorrectPassword: {
                   self.certificateDelegate?.onIncorrectPassword()
               }) {
                let creds = PKCS12.urlCredential(for: pkcs12)
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, creds)
            } else {
                self.certificateDelegate?.didAskForClientCertificate()
                completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
            }
        } else {
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

    // MARK: -

    func cancelAllQueue() {
        downloadQueue.cancelAll()
        downloadThumbnailQueue.cancelAll()
        downloadThumbnailActivityQueue.cancelAll()
        downloadThumbnailTrashQueue.cancelAll()
        downloadAvatarQueue.cancelAll()
        unifiedSearchQueue.cancelAll()
        saveLivePhotoQueue.cancelAll()
        convertLivePhotoQueue.cancelAll()
    }

    func cancelAllTask() {
        cancelAllQueue()
        cancelAllDataTask()
        cancelAllDownloadUploadTask()
    }

    func cancelAllDownloadTask() {
        NCNetworking.shared.cancelDownloadTasks()
        NCNetworking.shared.cancelDownloadBackgroundTask()
    }

    func cancelAllUploadTask() {
        NCNetworking.shared.cancelUploadTasks()
        NCNetworking.shared.cancelUploadBackgroundTask()
    }

    func cancelAllDownloadUploadTask() {
        cancelAllDownloadTask()
        cancelAllUploadTask()
    }

    func cancelTask(metadata: tableMetadata) {
        utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))

        // No session found
        if metadata.session.isEmpty {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
            return
        }

        /// DOWNLOAD
        ///
        if metadata.session.contains("download") {

            if metadata.session == NCNetworking.shared.sessionDownload {
                NCNetworking.shared.cancelDownloadTasks(metadata: metadata)
            } else if metadata.session == NCNetworking.shared.sessionDownloadBackground {
                NCNetworking.shared.cancelDownloadBackgroundTask(metadata: metadata)
            }

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account],
                                                        second: 0.2)
        }

        /// UPLOAD
        ///
        if metadata.session.contains("upload") {

            if metadata.session == NextcloudKit.shared.nkCommonInstance.identifierSessionUpload {
                NCNetworking.shared.cancelUploadTasks(metadata: metadata)
            } else {
                NCNetworking.shared.cancelUploadBackgroundTask(metadata: metadata)
            }

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account],
                                                        second: 0.2)
        }
    }

    func cancelAllDataTask() {
        NextcloudKit.shared.nkCommonInstance.nksessions.forEach { session in
            session.sessionData.session.getTasksWithCompletionHandler { dataTasks, _, _ in
                dataTasks.forEach { task in
                    task.cancel()
                }
            }
        }
    }

    func verifyZombie() async {
        var metadatas: [tableMetadata] = []
        /// UPLOADING-FOREGROUND -> DELETE
        ///
        metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                                NCNetworking.shared.sessionUpload,
                                                                                        NCGlobal.shared.metadataStatusUploading))
        for metadata in metadatas {
            var foundTask = false
            if let nkSession = NextcloudKit.shared.getSession(account: metadata.account) {
                let tasks = await nkSession.sessionData.session.tasks
                for task in tasks.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                    if metadata.account == nkSession.account,
                       metadata.session == NCNetworking.shared.sessionUpload,
                       metadata.sessionTaskIdentifier == task.taskIdentifier {
                        foundTask = true
                    }
                }
            }
            if !foundTask {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            }
        }

        /// DOWNLOADING-FOREGROUND -> STATUS: NORMAL
        ///
        metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                                NCNetworking.shared.sessionDownload,
                                                                                        NCGlobal.shared.metadataStatusDownloading))
        for metadata in metadatas {
            var foundTask = false
            if let nkSession = NextcloudKit.shared.getSession(account: metadata.account) {
                let tasks = await nkSession.sessionData.session.tasks
                for task in tasks.2 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                    if metadata.account == nkSession.account,
                       metadata.session == NCNetworking.shared.sessionDownload,
                       metadata.sessionTaskIdentifier == task.taskIdentifier {
                        foundTask = true
                    }
                }
            }
            if !foundTask {
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           session: "",
                                                           sessionError: "",
                                                           selector: "",
                                                           status: NCGlobal.shared.metadataStatusNormal)
            }
        }

        /// UPLOADING-BACKGROUND -> STATUS: WAIT UPLOAD
        ///
        metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d",
                                                                                NCNetworking.shared.sessionUploadBackground,
                                                                                NCNetworking.shared.sessionUploadBackgroundWWan,
                                                                                NCNetworking.shared.sessionUploadBackgroundExt,
                                                                                NCGlobal.shared.metadataStatusUploading))
        for metadata in metadatas {
            if let nkSession = NextcloudKit.shared.getSession(account: metadata.account) {
                var taskUpload: URLSessionTask?
                var session: URLSession?
                if metadata.session == NCNetworking.shared.sessionUploadBackground {
                    session = nkSession.sessionUploadBackground
                } else if metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan {
                    session = nkSession.sessionUploadBackgroundWWan
                } else if metadata.session == NCNetworking.shared.sessionUploadBackgroundExt {
                    session = nkSession.sessionUploadBackgroundExt
                }
                if let tasks = await session?.allTasks {
                    for task in tasks {
                        if metadata.account == nkSession.account,
                           metadata.sessionTaskIdentifier == task.taskIdentifier {
                            taskUpload = task
                        }
                    }
                    if taskUpload == nil, let metadata = NCManageDatabase.shared.getResultMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d",
                                                                                                                          metadata.ocId,
                                                                                                                          NCGlobal.shared.metadataStatusUploading)) {
                        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                                   session: NCNetworking.shared.sessionUploadBackground,
                                                                   sessionError: "",
                                                                   status: NCGlobal.shared.metadataStatusWaitUpload)
                    }
                }
            } else {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            }
        }

        /// DOWNLOADING-BACKGROUND -> STATUS: NORMAL
        ///
        metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                                NCNetworking.shared.sessionDownloadBackground,
                                                                                NCGlobal.shared.metadataStatusDownloading))
        for metadata in metadatas {
            if let nkSession = NextcloudKit.shared.getSession(account: metadata.account) {
                var taskDownload: URLSessionTask?
                let session: URLSession? = nkSession.sessionDownloadBackground
                if let tasks = await session?.allTasks {
                    for task in tasks {
                        if metadata.sessionTaskIdentifier == task.taskIdentifier {
                            taskDownload = task
                        }
                    }
                    if taskDownload == nil, let metadata = NCManageDatabase.shared.getResultMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d",
                                                                                                                            metadata.ocId,
                                                                                                                            NCGlobal.shared.metadataStatusDownloading)) {
                        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                                   session: "",
                                                                   sessionError: "",
                                                                   selector: "",
                                                                   status: NCGlobal.shared.metadataStatusNormal)
                    }
                }
            } else {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            }
        }
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

        if let trust: SecTrust = protectionSpace.serverTrust,
           let certificates = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]),
           let certificate = certificates.first {

            // extarct certificate txt
            saveX509Certificate(certificate, host: host, directoryCertificate: directoryCertificate)

            let isServerTrusted = SecTrustEvaluateWithError(trust, nil)
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

    private func getActiveAccountCertificate(account: String) {
        (self.p12Data, self.p12Password) = NCKeychain().getClientCertificate(account: account)
    }
}
