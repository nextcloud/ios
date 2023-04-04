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

@objc public protocol NCNetworkingDelegate {
    @objc optional func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Int64, description: String?, task: URLSessionTask, error: NKError)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, error: NKError)
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

    weak var delegate: NCNetworkingDelegate?

    var lastReachability: Bool = true
    var networkReachability: NKCommon.TypeReachability?
    let downloadRequest = ThreadSafeDictionary<String,DownloadRequest>()
    let uploadRequest = ThreadSafeDictionary<String,UploadRequest>()
    let uploadMetadataInBackground = ThreadSafeDictionary<String,tableMetadata>()

    lazy var nkBackground: NKBackground = {
        let nckb = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)
        return nckb
    }()
    
    public let sessionMaximumConnectionsPerHost = 5
    public let sessionIdentifierBackground: String = "com.nextcloud.session.upload.background"
    public let sessionIdentifierBackgroundWWan: String = "com.nextcloud.session.upload.backgroundWWan"
    public let sessionIdentifierBackgroundExtension: String = "com.nextcloud.session.upload.extension"

    public lazy var sessionManagerBackground: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifierBackground)
        configuration.allowsCellularAccess = true
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = sessionMaximumConnectionsPerHost
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: nkBackground, delegateQueue: OperationQueue.main)
        return session
    }()

    public lazy var sessionManagerBackgroundWWan: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifierBackgroundWWan)
        configuration.allowsCellularAccess = false
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = sessionMaximumConnectionsPerHost
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: nkBackground, delegateQueue: OperationQueue.main)
        return session
    }()

#if EXTENSION
    public lazy var sessionManagerBackgroundExtension: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifierBackgroundExtension)
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

    // MARK: - init

    override init() {
        super.init()

#if EXTENSION
        print("Start Background Extension: ", sessionIdentifierBackgroundExtension)
#else
        print("Start Background: ", sessionManagerBackground)
        print("Start BackgroundWWan: ", sessionManagerBackgroundWWan)
#endif
    }

    // MARK: - Communication Delegate

    func networkReachabilityObserver(_ typeReachability: NKCommon.TypeReachability) {

#if !EXTENSION
        if typeReachability == NKCommon.TypeReachability.reachableCellular || typeReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
            if !lastReachability {
                NCService.shared.startRequestServicesServer()
            }
            lastReachability = true
        } else {
            if lastReachability {
                let error = NKError(errorCode: NCGlobal.shared.errorNetworkNotAvailable, errorDescription: "")
                NCContentPresenter.shared.messageNotification("_network_not_available_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info)
            }
            lastReachability = false
        }
        networkReachability = typeReachability
#endif
    }

    func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        DispatchQueue.global().async {
            self.checkTrustedChallenge(session, didReceive: challenge, completionHandler: completionHandler)
        }
    }

    func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.downloadProgress?(progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected, fileName: fileName, serverUrl: serverUrl, session: session, task: task)
    }

    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Int64, description: String?, task: URLSessionTask, error: NKError) {
        delegate?.downloadComplete?(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, description: description, task: task, error: error)
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

    // MARK: - Pinning check

    public func checkTrustedChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        let protectionSpace: URLProtectionSpace = challenge.protectionSpace
        let directoryCertificate = CCUtility.getDirectoryCerificates()!
        let host = challenge.protectionSpace.host
        let certificateSavedPath = directoryCertificate + "/" + host + ".der"
        var isTrusted: Bool

        NextcloudKit.shared.nkCommonInstance.writeLog("[PINNING] Start")

        if let serverTrust: SecTrust = protectionSpace.serverTrust, let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {

            NextcloudKit.shared.nkCommonInstance.writeLog("[PINNING] Extarct certificate txt")

            // extarct certificate txt
            saveX509Certificate(certificate, host: host, directoryCertificate: directoryCertificate)
           
            let isServerTrusted = SecTrustEvaluateWithError(serverTrust, nil)            
            let certificateCopyData = SecCertificateCopyData(certificate)
            let data = CFDataGetBytePtr(certificateCopyData);
            let size = CFDataGetLength(certificateCopyData);
            let certificateData = NSData(bytes: data, length: size)
                
            certificateData.write(toFile: directoryCertificate + "/" + host + ".tmp", atomically: true)
            
            if isServerTrusted {
                NextcloudKit.shared.nkCommonInstance.writeLog("[PINNING] Server trusted")
                isTrusted = true
            } else if let certificateDataSaved = NSData(contentsOfFile: certificateSavedPath), certificateData.isEqual(to: certificateDataSaved as Data) {
                NextcloudKit.shared.nkCommonInstance.writeLog("[PINNING] Server trusted (data saved)")
                isTrusted = true
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[PINNING] Server not trusted")
                isTrusted = false
            }
        } else {
            NextcloudKit.shared.nkCommonInstance.writeLog("[PINNING] not certificate, server not trusted ")
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

        let directoryCertificate = CCUtility.getDirectoryCerificates()!
        let certificateAtPath = directoryCertificate + "/" + host + ".tmp"
        let certificateToPath = directoryCertificate + "/" + host + ".der"

        if !NCUtilityFileSystem.shared.copyFile(atPath: certificateAtPath, toPath: certificateToPath) {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Write certificare error")
        }
    }
    
    private func saveX509Certificate(_ certificate: SecCertificate, host: String, directoryCertificate: String) {
        
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

    func checkPushNotificationServerProxyCertificateUntrusted(viewController: UIViewController?, completion: @escaping (_ error: NKError) -> Void) {
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
                    if let navigationController = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil).instantiateInitialViewController() as? UINavigationController {
                        let vcCertificateDetails = navigationController.topViewController as! NCViewCertificateDetails
                        vcCertificateDetails.host = host
                        viewController?.present(navigationController, animated: true)
                    }
                }))
                viewController?.present(alertController, animated: true)
            }
        }
    }

    // MARK: - Utility

    func cancelTaskWithUrl(_ url: URL) {
        NextcloudKit.shared.getSessionManager().getAllTasks { tasks in
            tasks.filter { $0.state == .running }.filter { $0.originalRequest?.url == url }.first?.cancel()
        }
    }

    @objc func cancelAllTask() {
        NextcloudKit.shared.getSessionManager().getAllTasks { tasks in
            for task in tasks {
                task.cancel()
            }
        }
    }

    func isInTaskUploadBackground(fileName: String, completion: @escaping (_ exists: Bool) -> Void) {

        let sessions: [URLSession] = [NCNetworking.shared.sessionManagerBackground, NCNetworking.shared.sessionManagerBackgroundWWan]

        for session in sessions {
            session.getAllTasks(completionHandler: { tasks in
                for task in tasks {
                    let url = task.originalRequest?.url
                    let urlFileName = url?.lastPathComponent
                    if urlFileName == fileName {
                        completion(true)
                    }
                }
                if session == sessions.last {
                    completion(false)
                }
            })
        }
    }

    // MARK: - Download

    func cancelDownload(ocId: String, serverUrl: String, fileNameView: String) {

        guard let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView) else { return }

        if let request = downloadRequest[fileNameLocalPath] {
            request.cancel()
        } else if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
            NCManageDatabase.shared.setMetadataSession(ocId: ocId, session: "", sessionError: "", sessionSelector: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])
        }
    }

    func download(metadata: tableMetadata, selector: String, notificationCenterProgressTask: Bool = true,
                  requestHandler: @escaping (_ request: DownloadRequest) -> () = { _ in },
                  progressHandler: @escaping (_ progress: Progress) -> Void = { _ in },
                  completion: @escaping (_ afError: AFError?, _ error: NKError) -> Void) {

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!

        if NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) == nil {
            NCManageDatabase.shared.addMetadata(tableMetadata.init(value: metadata))
        }

        if metadata.isDownloadUpload { return }

        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload, sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusInDownload)

        NextcloudKit.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue, requestHandler: { request in

            requestHandler(request)
            
            self.downloadRequest[fileNameLocalPath] = request

            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusDownloading)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadStartFile, userInfo: ["ocId":metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])
            
        }, taskHandler: { (_) in
            
        }, progressHandler: { (progress) in
            
            if notificationCenterProgressTask {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterProgressTask, object: nil, userInfo: ["account":metadata.account, "ocId":metadata.ocId, "fileName":metadata.fileName, "serverUrl":metadata.serverUrl, "status":NSNumber(value: NCGlobal.shared.metadataStatusInDownload), "progress":NSNumber(value: progress.fractionCompleted), "totalBytes":NSNumber(value: progress.totalUnitCount), "totalBytesExpected":NSNumber(value: progress.completedUnitCount)])
            }
            progressHandler(progress)
                                        
        }) { (account, etag, date, _, allHeaderFields, afError, error) in

            self.downloadRequest.removeValue(forKey:fileNameLocalPath)

            if afError?.isExplicitlyCancelledError ?? false {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])

            } else if error == .success {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal, etag: etag)
                NCManageDatabase.shared.addLocalFile(metadata: metadata)
#if !EXTENSION
                if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@", metadata.fileName, metadata.serverUrl)) {
                    NCEndToEndEncryption.sharedManager()?.decryptFile(metadata.fileName, fileNameView: metadata.fileNameView, ocId: metadata.ocId, key: result.key, initializationVector: result.initializationVector, authenticationTag: result.authenticationTag)
                }
                CCUtility.setExif(metadata) { _, _, _, _, _ in }
#endif
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "selector": selector, "error": error])

            } else {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: error.errorDescription, sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusDownloadError)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "selector": selector, "error": error])
            }

            DispatchQueue.main.async { completion(afError, error) }
        }
    }

    // MARK: - Upload

    func upload(metadata: tableMetadata,
                uploadE2EEDelegate: uploadE2EEDelegate? = nil,
                start: @escaping () -> () = { },
                progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> () = { _, _, _ in },
                completion: @escaping (_ error: NKError) -> () = { error in }) {

        let metadata = tableMetadata.init(value: metadata)
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload file \(metadata.fileNameView) with Identifier \(metadata.assetLocalIdentifier) with size \(metadata.size) [CHUNCK \(metadata.chunk), E2EE \(metadata.isDirectoryE2EE)]")

        if metadata.isDirectoryE2EE {
#if !EXTENSION_FILE_PROVIDER_EXTENSION && !EXTENSION_WIDGET
            Task {
                let error = await NCNetworkingE2EEUpload.shared.upload(metadata: metadata, uploadE2EEDelegate: uploadE2EEDelegate)
                completion(error)
            }
#endif
        } else if metadata.chunk {
            uploadChunkedFile(metadata: metadata, start: start, progressHandler: progressHandler) { error in
                completion(error)
            }
        } else if metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload {
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            uploadFile(metadata: metadata, fileNameLocalPath:fileNameLocalPath, start: start, progressHandler: progressHandler) { account, ocId, etag, date, size, allHeaderFields, afError, error in
                completion(error)
            }
        } else {
            uploadFileInBackground(metadata: metadata, start: start) { error in
                completion(error)
            }
        }
    }

    func uploadFile(metadata: tableMetadata, fileNameLocalPath: String, withUploadComplete: Bool = true ,addCustomHeaders: [String: String]? = nil,
                    start: @escaping () -> () = { },
                    progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> () = { _, _, _ in },
                    completion: @escaping (_ account: String, _ ocId: String?, _ etag: String?, _ date: NSDate?, _ size: Int64, _ allHeaderFields: [AnyHashable : Any]?, _ afError: AFError?, _ error: NKError) -> Void) {

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        var uploadTask: URLSessionTask?
        let description = metadata.ocId

        NextcloudKit.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, customUserAgent: nil, addCustomHeaders: addCustomHeaders, requestHandler: { request in

            self.uploadRequest[fileNameLocalPath] = request

        }, taskHandler: { task in

            uploadTask = task
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "sessionSelector": metadata.sessionSelector])
            start()

        }, progressHandler: { progress in

            NotificationCenter.default.postOnMainThread(
                name: NCGlobal.shared.notificationCenterProgressTask,
                userInfo: [
                    "account": metadata.account,
                    "ocId": metadata.ocId,
                    "fileName": metadata.fileName,
                    "serverUrl": metadata.serverUrl,
                    "status": NSNumber(value: NCGlobal.shared.metadataStatusInUpload),
                    "progress": NSNumber(value: progress.fractionCompleted),
                    "totalBytes": NSNumber(value: progress.totalUnitCount),
                    "totalBytesExpected": NSNumber(value: progress.completedUnitCount)])

            progressHandler(progress.completedUnitCount, progress.totalUnitCount, progress.fractionCompleted)

        }) { account, ocId, etag, date, size, allHeaderFields, afError, error in

            self.uploadRequest.removeValue(forKey: fileNameLocalPath)
            if withUploadComplete, let uploadTask = uploadTask {
                self.uploadComplete(fileName: metadata.fileName, serverUrl: metadata.serverUrl, ocId: ocId, etag: etag, date: date, size: size, description: description, task: uploadTask, error: error)
            }
            completion(account, ocId, etag, date, size, allHeaderFields, afError, error)
        }
    }

    private func uploadFileInBackground(metadata: tableMetadata,
                                        start: @escaping () -> () = { },
                                        completion: @escaping (_ error: NKError) -> Void) {

        var session: URLSession?
        let metadata = tableMetadata.init(value: metadata)
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

        if metadata.session == sessionIdentifierBackground || metadata.session == sessionIdentifierBackgroundExtension {
            session = sessionManagerBackground
        } else if metadata.session == sessionIdentifierBackgroundWWan {
            session = sessionManagerBackgroundWWan
        }

        start()

        // Check file dim > 0
        if NCUtilityFileSystem.shared.getFileSize(filePath: fileNameLocalPath) == 0 && metadata.size != 0 {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            completion(NKError(errorCode: NCGlobal.shared.errorResourceNotFound, errorDescription: NSLocalizedString("_error_not_found_", value: "The requested resource could not be found", comment: "")))

        } else {

            if let task = nkBackground.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, description: metadata.ocId, session: session!) {

                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload file \(metadata.fileNameView) with task with taskIdentifier \(task.taskIdentifier)")

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "sessionSelector": metadata.sessionSelector])
                completion(NKError())

            } else {

                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                completion(NKError(errorCode: NCGlobal.shared.errorResourceNotFound, errorDescription: "task null"))
            }
        }
    }

    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, error: NKError) {
        var isApplicationStateActive = false
#if !EXTENSION
        isApplicationStateActive = UIApplication.shared.applicationState == .active
#endif
        DispatchQueue.global().async {
            guard self.delegate == nil, let metadata = NCManageDatabase.shared.getMetadataFromOcId(description) else {
                self.delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size: size, description: description, task: task, error: error)
                return
            }
            let ocIdTemp = metadata.ocId
            let selector = metadata.sessionSelector

            if error == .success, let ocId = ocId, size == metadata.size {

                let metadata = tableMetadata.init(value: metadata)

                metadata.uploadDate = date ?? NSDate()
                metadata.etag = etag ?? ""
                metadata.ocId = ocId

                if let fileId = NCUtility.shared.ocIdToFileId(ocId: ocId) {
                    metadata.fileId = fileId
                }

                metadata.session = ""
                metadata.sessionError = ""
                metadata.sessionTaskIdentifier = 0
                metadata.status = NCGlobal.shared.metadataStatusNormal

                // Delete Asset on Photos album
                if CCUtility.getRemovePhotoCameraRoll() && !metadata.assetLocalIdentifier.isEmpty {
                    metadata.deleteAssetLocalIdentifier = true
                }

                NCManageDatabase.shared.addMetadata(metadata)
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))

                if selector == NCGlobal.shared.selectorUploadFileNODelete {
                    NCUtilityFileSystem.shared.moveFile(atPath: CCUtility.getDirectoryProviderStorageOcId(ocIdTemp), toPath: CCUtility.getDirectoryProviderStorageOcId(ocId))
                    NCManageDatabase.shared.addLocalFile(metadata: metadata)
                } else {
                    NCUtilityFileSystem.shared.deleteFile(filePath: CCUtility.getDirectoryProviderStorageOcId(ocIdTemp))
                }

                NextcloudKit.shared.nkCommonInstance.writeLog("[SUCCESS] Upload complete " + serverUrl + "/" + fileName + ", result: success(\(size) bytes)")
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": error])

            } else {

                if error.errorCode == NSURLErrorCancelled || error.errorCode == NCGlobal.shared.errorRequestExplicityCancelled {

                    CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])

                } else if error.errorCode == NCGlobal.shared.errorForbidden && isApplicationStateActive {

                    DispatchQueue.main.async {
                        let newFileName = NCUtilityFileSystem.shared.createFileName(metadata.fileName, serverUrl: metadata.serverUrl, account: metadata.account)
                        let alertController = UIAlertController(title: error.errorDescription, message: NSLocalizedString("_change_upload_filename_", comment: ""), preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: String(format: NSLocalizedString("_save_file_as_", comment: ""), newFileName), style: .default, handler: { action in
                            let atpath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                            let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + newFileName
                            NCUtilityFileSystem.shared.moveFile(atPath: atpath, toPath: toPath)
                            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, newFileName: newFileName, session: nil, sessionError: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusWaitUpload)
                        }))
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive, handler: { action in
                            CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])
                        }))
#if !EXTENSION
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        appDelegate.window?.rootViewController?.present(alertController, animated: true)
#endif
                    }

                } else {
                    
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: error.errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": error])
                }
            }

            // Update Badge
            let counterBadge = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d OR status == %d OR status == %d", NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusInUpload, NCGlobal.shared.metadataStatusUploading))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUpdateBadgeNumber, userInfo: ["counter":counterBadge.count])

            self.uploadMetadataInBackground.removeValue(forKey: fileName + serverUrl)
            self.delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size: size, description: description, task: task, error: error)
        }
    }

    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
        DispatchQueue.global().async {
            self.delegate?.uploadProgress?(progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected, fileName: fileName, serverUrl: serverUrl, session: session, task: task)

            var metadata: tableMetadata?
            let description: String = task.taskDescription ?? ""

            if let metadataTmp = self.uploadMetadataInBackground[fileName+serverUrl] {
                metadata = metadataTmp
            } else if let metadataTmp = NCManageDatabase.shared.getMetadataFromOcId(description) {
                self.uploadMetadataInBackground[fileName+serverUrl] = metadataTmp
                metadata = metadataTmp
            }

            if let metadata = metadata {
                NotificationCenter.default.postOnMainThread(
                    name: NCGlobal.shared.notificationCenterProgressTask,
                    userInfo: [
                        "account": metadata.account,
                        "ocId": metadata.ocId,
                        "fileName": metadata.fileName,
                        "serverUrl": serverUrl,
                        "status": NSNumber(value: NCGlobal.shared.metadataStatusInUpload),
                        "progress": NSNumber(value: progress),
                        "totalBytes": NSNumber(value: totalBytes),
                        "totalBytesExpected": NSNumber(value: totalBytesExpected)])
            }
        }
    }

    func getOcIdInBackgroundSession(queue: DispatchQueue = .main, completion: @escaping (_ listOcId: [String]) -> Void) {

        var listOcId: [String] = []

        sessionManagerBackground.getAllTasks(completionHandler: { tasks in
            for task in tasks {
                listOcId.append(task.description)
            }
            self.sessionManagerBackgroundWWan.getAllTasks(completionHandler: { tasks in
                for task in tasks {
                    listOcId.append(task.description)
                }
                queue.async { completion(listOcId) }
            })
        })
    }

    // MARK: - Transfer (Download Upload)

    @objc func cancelTransferMetadata(_ metadata: tableMetadata, completion: @escaping () -> Void) {

        let metadata = tableMetadata.init(value: metadata)
        
        if metadata.session.count == 0 {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            return completion()
        }

        if metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload {

            NCNetworking.shared.cancelDownload(ocId: metadata.ocId, serverUrl: metadata.serverUrl, fileNameView: metadata.fileNameView)
            return completion()
        }

        if metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload || metadata.chunk {

            guard let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView) else { return }

            if let request = uploadRequest[fileNameLocalPath] {
                request.cancel()
            } else {
                CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])
            }

            return completion()
        }

        var session: URLSession?
        if metadata.session == NCNetworking.shared.sessionIdentifierBackground {
            session = NCNetworking.shared.sessionManagerBackground
        } else if metadata.session == NCNetworking.shared.sessionIdentifierBackgroundWWan {
            session = NCNetworking.shared.sessionManagerBackgroundWWan
        }
        if session == nil {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])
            return completion()
        }

        session?.getTasksWithCompletionHandler { _, uploadTasks, _ in

            var cancel = false
            if metadata.session.count > 0 && metadata.session.contains("upload") {
                for task in uploadTasks {
                    if task.taskIdentifier == metadata.sessionTaskIdentifier {
                        task.cancel()
                        cancel = true
                    }
                }
                if cancel == false {
                    do {
                        try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                    } catch { }
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])
                }
            }
            completion()
        }
    }

    @objc func cancelAllTransfer(account: String, completion: @escaping () -> Void) {

        NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "status == %d OR status == %d", account, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploadError))

        let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status != %d", NCGlobal.shared.metadataStatusNormal))

        var counter = 0
        for metadata in metadatas {
            counter += 1
            if metadata.status == NCGlobal.shared.metadataStatusWaitDownload || metadata.status == NCGlobal.shared.metadataStatusDownloadError {
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal)
            }
            if metadata.status == NCGlobal.shared.metadataStatusDownloading || metadata.status == NCGlobal.shared.metadataStatusUploading {
                self.cancelTransferMetadata(metadata) {
                    if counter == metadatas.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            completion()
                        }
                    }
                }
            }
        }

#if !EXTENSION
        NCOperationQueue.shared.downloadCancelAll()
#endif
    }

    func cancelAllDownloadTransfer() {

        let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status != %d", NCGlobal.shared.metadataStatusNormal))
        for metadata in metadatas {
            if metadata.status == NCGlobal.shared.metadataStatusWaitDownload || metadata.status == NCGlobal.shared.metadataStatusDownloadError {
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal)
            }
            if metadata.status == NCGlobal.shared.metadataStatusDownloading && metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload {
                cancelDownload(ocId: metadata.ocId, serverUrl: metadata.serverUrl, fileNameView: metadata.fileNameView)
            }
        }

#if !EXTENSION
        NCOperationQueue.shared.downloadCancelAll()
#endif
    }

    // MARK: - WebDav Read file, folder

    @objc func readFolder(serverUrl: String, account: String, completion: @escaping (_ account: String, _ metadataFolder: tableMetadata?, _ metadatas: [tableMetadata]?, _ metadatasUpdate: [tableMetadata]?, _ metadatasLocalUpdate: [tableMetadata]?, _ metadatasDelete: [tableMetadata]?, _ error: NKError) -> Void) {

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: CCUtility.getShowHiddenFiles(), includeHiddenFiles: NCGlobal.shared.includeHiddenFiles ,options: options) { account, files, _, error in
            guard error == .success else {
                completion(account, nil, nil, nil, nil, nil, error)
                return
            }

            NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: true) { metadataFolder, metadatasFolder, metadatas in

                // Add metadata folder
                NCManageDatabase.shared.addMetadata(tableMetadata.init(value: metadataFolder))

                // Update directory
                NCManageDatabase.shared.addDirectory(encrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, serverUrl: serverUrl, account: metadataFolder.account)
                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, richWorkspace: metadataFolder.richWorkspace, account: metadataFolder.account)

                // Update sub directories NO Update richWorkspace
                for metadata in metadatasFolder {
                    let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                    NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, account: account)
                }

                let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, NCGlobal.shared.metadataStatusNormal))
                let metadatasChanged = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareEtagLocal: true)

                completion(account, metadataFolder, metadatas, metadatasChanged.metadatasUpdate, metadatasChanged.metadatasLocalUpdate, metadatasChanged.metadatasDelete, error)
            }
        }
    }

    func readFile(serverUrlFileName: String, showHiddenFiles: Bool = CCUtility.getShowHiddenFiles(), queue: DispatchQueue = NextcloudKit.shared.nkCommonInstance.backgroundQueue, completion: @escaping (_ account: String, _ metadata: tableMetadata?, _ error: NKError) -> Void) {

        let options = NKRequestOptions(queue: queue)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, options: options) { account, files, _, error in
            guard error == .success, files.count == 1, let file = files.first else {
                completion(account, nil, error)
                return
            }

            let isDirectoryE2EE = NCUtility.shared.isDirectoryE2EE(file: file)
            let metadata = NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)

            completion(account, metadata, error)
        }
    }

    func fileExists(serverUrlFileName: String, completion: @escaping (_ account: String, _ exists: Bool?, _ file: NKFile?, _ error: NKError) -> Void) {

        /*
        let requestBody =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:prop>
                <d:getlastmodified />
                <d:getetag />
                <permissions xmlns=\"http://owncloud.org/ns\"/>
                <id xmlns=\"http://owncloud.org/ns\"/>
                <fileid xmlns=\"http://owncloud.org/ns\"/>
                <size xmlns=\"http://owncloud.org/ns\"/>
            </d:prop>
        </d:propfind>
        """
        */
        let requestBody =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:prop></d:prop>
        </d:propfind>
        """
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", requestBody: requestBody.data(using: .utf8), options: options) { account, files, _, error in
            if error == .success, let file = files.first {
                completion(account, true, file, error)
            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                completion(account, false, nil, error)
            } else {
                completion(account, nil, nil, error)
            }
        }
    }
    
    //MARK: - Search
    
    /// WebDAV search
    func searchFiles(urlBase: NCUserBaseUrl, literal: String, completion: @escaping (_ metadatas: [tableMetadata]?, _ error: NKError) -> ()) {

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.searchLiteral(serverUrl: urlBase.urlBase, depth: "infinity", literal: literal, showHiddenFiles: CCUtility.getShowHiddenFiles(), options: options) { (account, files, data, error) in
            guard error == .success else {
                return completion(nil, error)
            }

            NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, metadatasFolder, metadatas in

                // Update sub directories
                for folder in metadatasFolder {
                    let serverUrl = folder.serverUrl + "/" + folder.fileName
                    NCManageDatabase.shared.addDirectory(encrypted: folder.e2eEncrypted, favorite: folder.favorite, ocId: folder.ocId, fileId: folder.fileId, etag: nil, permissions: folder.permissions, serverUrl: serverUrl, account: account)
                }

                NCManageDatabase.shared.addMetadatas(metadatas)
                let metadatas = Array(metadatas.map(tableMetadata.init))
                completion(metadatas, error)
            }
        }
    }

    /// Unified Search (NC>=20)
    ///
    func unifiedSearchFiles(userBaseUrl: NCUserBaseUrl, literal: String, providers: @escaping (_ accout: String, _ searchProviders: [NKSearchProvider]?) -> Void, update: @escaping (_ account: String, _ id: String, NKSearchResult?, [tableMetadata]?) -> Void, completion: @escaping (_ account: String, _ error: NKError) -> ()) {

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        dispatchGroup.notify(queue: .main) {
            completion(userBaseUrl.account, NKError())
        }

        NextcloudKit.shared.unifiedSearch(term: literal, timeout: 30, timeoutProvider: 90) { provider in
            // example filter
            // ["calendar", "files", "fulltextsearch"].contains(provider.id)
            return true
        } request: { request in
            if let request = request {
                self.requestsUnifiedSearch.append(request)
            }
        } providers: { account, searchProviders in
            providers(account, searchProviders)
        } update: { account, partialResult, provider, error in
            guard let partialResult = partialResult else { return }
            var metadatas: [tableMetadata] = []

            switch provider.id {
            case "files":
                partialResult.entries.forEach({ entry in
                    if let fileId = entry.fileId,
                       let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && fileId == %@", userBaseUrl.userAccount, String(fileId))) {
                        metadatas.append(metadata)
                    } else if let filePath = entry.filePath {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: filePath, dispatchGroup: dispatchGroup) { account, metadata, error in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    } else { print(#function, "[ERROR]: File search entry has no path: \(entry)") }
                })
                break
            case "fulltextsearch":
                // NOTE: FTS could also return attributes like files
                // https://github.com/nextcloud/files_fulltextsearch/issues/143
                partialResult.entries.forEach({ entry in
                    let url = URLComponents(string: entry.resourceURL)
                    guard let dir = url?.queryItems?["dir"]?.value, let filename = url?.queryItems?["scrollto"]?.value else { return }
                    if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(
                              format: "account == %@ && path == %@ && fileName == %@",
                              userBaseUrl.userAccount,
                              "/remote.php/dav/files/" + userBaseUrl.user + dir,
                              filename)) {
                        metadatas.append(metadata)
                    } else {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: dir + filename, dispatchGroup: dispatchGroup) { account, metadata, error in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                })
            default:
                partialResult.entries.forEach({ entry in
                    let metadata = NCManageDatabase.shared.createMetadata(account: userBaseUrl.account, user: userBaseUrl.user, userId: userBaseUrl.userId, fileName: entry.title, fileNameView: entry.title, ocId: NSUUID().uuidString, serverUrl: userBaseUrl.urlBase, urlBase: userBaseUrl.urlBase, url: entry.resourceURL, contentType: "", isUrl: true, name: partialResult.id, subline: entry.subline, iconName: entry.icon, iconUrl: entry.thumbnailURL)
                    metadatas.append(metadata)
                })
            }
            update(account, provider.id, partialResult, metadatas)
        } completion: { account, data, error in
            self.requestsUnifiedSearch.removeAll()
            dispatchGroup.leave()
        }
    }

    func unifiedSearchFilesProvider(userBaseUrl: NCUserBaseUrl, id: String, term: String, limit: Int, cursor: Int, completion: @escaping (_ account: String, _ searchResult: NKSearchResult?, _ metadatas: [tableMetadata]?, _ error: NKError) -> ()) {

        var metadatas: [tableMetadata] = []

        let request = NextcloudKit.shared.searchProvider(id, account: userBaseUrl.account, term: term, limit: limit, cursor: cursor, timeout: 60) { account, searchResult, data, error in
            guard let searchResult = searchResult else {
                completion(account, nil, metadatas, error)
                return
            }

            switch id {
            case "files":
                searchResult.entries.forEach({ entry in
                    if let fileId = entry.fileId, let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && fileId == %@", userBaseUrl.userAccount, String(fileId))) {
                        metadatas.append(metadata)
                    } else if let filePath = entry.filePath {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: filePath, dispatchGroup: nil) { account, metadata, error in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    } else { print(#function, "[ERROR]: File search entry has no path: \(entry)") }
                })
                break
            case "fulltextsearch":
                // NOTE: FTS could also return attributes like files
                // https://github.com/nextcloud/files_fulltextsearch/issues/143
                searchResult.entries.forEach({ entry in
                    let url = URLComponents(string: entry.resourceURL)
                    guard let dir = url?.queryItems?["dir"]?.value, let filename = url?.queryItems?["scrollto"]?.value else { return }
                    if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && path == %@ && fileName == %@", userBaseUrl.userAccount, "/remote.php/dav/files/" + userBaseUrl.user + dir, filename)) {
                        metadatas.append(metadata)
                    } else {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: dir + filename, dispatchGroup: nil) { account, metadata, error in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                })
            default:
                searchResult.entries.forEach({ entry in
                    let newMetadata = NCManageDatabase.shared.createMetadata(account: userBaseUrl.account, user: userBaseUrl.user, userId: userBaseUrl.userId, fileName: entry.title, fileNameView: entry.title, ocId: NSUUID().uuidString, serverUrl: userBaseUrl.urlBase, urlBase: userBaseUrl.urlBase, url: entry.resourceURL, contentType: "", isUrl: true, name: searchResult.name.lowercased(), subline: entry.subline, iconName: entry.icon, iconUrl: entry.thumbnailURL)
                    metadatas.append(newMetadata)
                })
            }

            completion(account, searchResult, metadatas, error)
        }
        if let request = request {
            requestsUnifiedSearch.append(request)
        }
    }

    func cancelUnifiedSearchFiles() {
        for request in requestsUnifiedSearch {
            request.cancel()
        }
        requestsUnifiedSearch.removeAll()
    }

    private func loadMetadata(userBaseUrl: NCUserBaseUrl, filePath: String, dispatchGroup: DispatchGroup? = nil, completion: @escaping (String, tableMetadata, NKError) -> Void) {
        let urlPath = userBaseUrl.urlBase + "/remote.php/dav/files/" + userBaseUrl.user + filePath
        dispatchGroup?.enter()
        self.readFile(serverUrlFileName: urlPath) { account, metadata, error in
            defer { dispatchGroup?.leave() }
            guard let metadata = metadata else { return }
            let returnMetadata = tableMetadata.init(value: metadata)
            NCManageDatabase.shared.addMetadata(metadata)
            completion(account, returnMetadata, error)
        }
    }

    // MARK: - WebDav Create Folder

    func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, userId: String, overwrite: Bool = false, withPush:Bool, completion: @escaping (_ error: NKError) -> Void) {

        let isDirectoryEncrypted = NCUtility.shared.isDirectoryE2EE(serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId)
        let fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isDirectoryEncrypted {
#if !EXTENSION
            Task {
                let error = await NCNetworkingE2EECreateFolder.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId, withPush: withPush)
                completion(error)
            }
#endif
        } else {
            createFolderPlain(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, overwrite: overwrite, withPush: withPush, completion: completion)
        }
    }

    private func createFolderPlain(fileName: String, serverUrl: String, account: String, urlBase: String, overwrite: Bool, withPush:Bool, completion: @escaping (_ error: NKError) -> Void) {

        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!

        if !overwrite {
            fileNameFolder = NCUtilityFileSystem.shared.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        }
        if fileNameFolder.count == 0 {
            return completion(NKError())
        }
        let fileNameFolderUrl = serverUrl + "/" + fileNameFolder

        NextcloudKit.shared.createFolder(serverUrlFileName: fileNameFolderUrl) { account, ocId, _, error in
            guard error == .success else {
                if error.errorCode == NCGlobal.shared.errordMethodNotSupported && overwrite {
                    completion(NKError())
                } else {
                    completion(error)
                }
                return
            }

            self.readFile(serverUrlFileName: fileNameFolderUrl) { (account, metadataFolder, error) in

                if error == .success {
                    if let metadata = metadataFolder {
                        NCManageDatabase.shared.addMetadata(metadata)
                        NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: fileNameFolderUrl, account: account)
                    }
                    if let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadataFolder?.ocId) {
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "e2ee": false, "withPush": withPush])
                    }
                }
                completion(error)
            }
        }
    }

    func createFolder(assets: [PHAsset], selector: String, useSubFolder: Bool, account: String, urlBase: String, userId: String, withPush:Bool) -> Bool {

        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: urlBase, userId: userId, account: account)
        let serverUrlBase = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: urlBase, userId: userId, account: account)
        let fileNameBase =  NCManageDatabase.shared.getAccountAutoUploadFileName()
        let autoUploadSubfolderGranularity = NCManageDatabase.shared.getAccountAutoUploadSubfolderGranularity()
        
        func createFolder(fileName: String, serverUrl: String) -> Bool {
            var result: Bool = false
            let semaphore = DispatchSemaphore(value: 0)
            NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId, overwrite: true, withPush: withPush) { error in
                if error == .success { result = true }
                semaphore.signal()
            }
            semaphore.wait()
            return result
        }

        func createNameSubFolder() -> [String] {

            var datesSubFolder: [String] = []
            let dateFormatter = DateFormatter()

            for asset in assets {
                let date = asset.creationDate ?? Date()
                dateFormatter.dateFormat = "yyyy"
                let year = dateFormatter.string(from: date)
                dateFormatter.dateFormat = "MM"
                let month = dateFormatter.string(from: date)
                dateFormatter.dateFormat = "dd"
                let day = dateFormatter.string(from: date)
                if autoUploadSubfolderGranularity == 0 {
                    datesSubFolder.append("\(year)")
                } else if autoUploadSubfolderGranularity == 2 {
                    datesSubFolder.append("\(year)/\(month)/\(day)")
                } else {  // Month Granularity is default
                    datesSubFolder.append("\(year)/\(month)")
                }
            }

            return Array(Set(datesSubFolder))
        }

        var result = createFolder(fileName: fileNameBase, serverUrl: serverUrlBase)

        if useSubFolder && result {
            for dateSubFolder in createNameSubFolder() {
                let subfolderArray = dateSubFolder.split(separator: "/")
                let year = subfolderArray[0]
                let serverUrlYear = autoUploadPath
                result = createFolder(fileName: String(year), serverUrl: serverUrlYear)  // Year always present independently of preference value
                if result && autoUploadSubfolderGranularity >= 1 {
                    let month = subfolderArray[1]
                    let serverUrlMonth = autoUploadPath + "/" + year
                    result = createFolder(fileName: String(month), serverUrl: serverUrlMonth)
                    if result && autoUploadSubfolderGranularity == 2 {
                        let day = subfolderArray[2]
                        let serverUrlDay = autoUploadPath + "/" + year + "/" + month
                        result = createFolder(fileName: String(day), serverUrl: serverUrlDay)
                    }
                }
                if !result { break }
            }
        }

        return result
    }

    // MARK: - WebDav Delete

    func deleteMetadata(_ metadata: tableMetadata, onlyLocalCache: Bool, completion: @escaping (_ error: NKError) -> Void) {

        if onlyLocalCache {

            var metadatas = [metadata]

            if metadata.directory {
                let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == false", metadata.account, serverUrl))
            }

            for metadata in metadatas {

                NCManageDatabase.shared.deleteVideo(metadata: metadata)
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCUtilityFileSystem.shared.deleteFile(filePath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))

                if let metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                    NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadataLivePhoto.ocId))
                    NCUtilityFileSystem.shared.deleteFile(filePath: CCUtility.getDirectoryProviderStorageOcId(metadataLivePhoto.ocId))
                }

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": metadata.ocId, "fileNameView": metadata.fileNameView, "serverUrl": metadata.serverUrl, "account": metadata.account, "classFile": metadata.classFile, "onlyLocalCache": true])
            }
            return completion(NKError())
        }

        let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)

        if metadata.isDirectoryE2EE {
#if !EXTENSION
            Task {
                if let metadataLive = metadataLive {
                    let error = await NCNetworkingE2EEDelete.shared.delete(metadata: metadataLive)
                    if error == .success {
                        let error = await NCNetworkingE2EEDelete.shared.delete(metadata: metadata)
                        completion(error)
                    } else {
                        completion(error)
                    }
                } else {
                    let error = await NCNetworkingE2EEDelete.shared.delete(metadata: metadata)
                    completion(error)
                }
            }
#endif
        } else {
            if metadataLive == nil {
                self.deleteMetadataPlain(metadata, customHeader: nil, completion: completion)
            } else {
                self.deleteMetadataPlain(metadataLive!, customHeader: nil) { error in
                    if error == .success {
                        self.deleteMetadataPlain(metadata, customHeader: nil, completion: completion)
                    } else {
                        completion(error)
                    }
                }
            }
        }
    }

    func deleteMetadataPlain(_ metadata: tableMetadata, customHeader: [String: String]?, completion: @escaping (_ error: NKError) -> Void) {

        // verify permission
        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanDelete)
        if metadata.permissions != "" && permission == false {
            return completion(NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_delete_file_"))
        }

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let options = NKRequestOptions(customHeader: customHeader)
        
        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, options: options) { account, error in

            if error == .success || error.errorCode == NCGlobal.shared.errorResourceNotFound {

                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }

                NCManageDatabase.shared.deleteVideo(metadata: metadata)
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

                if metadata.directory {
                    NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
                }

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": metadata.ocId, "fileNameView": metadata.fileNameView, "serverUrl": metadata.serverUrl, "account": metadata.account, "classFile": metadata.classFile, "onlyLocalCache": false])
            }

            completion(error)
        }
    }

    func deleteMetadataPlain(_ metadata: tableMetadata, customHeader: [String: String]?) async -> (NKError) {

        await withUnsafeContinuation({ continuation in
            self.deleteMetadataPlain(metadata, customHeader: customHeader) { error in
                continuation.resume(returning: error)
            }
        })
    }

    // MARK: - WebDav Favorite

    func favoriteMetadata(_ metadata: tableMetadata, completion: @escaping (_ error: NKError) -> Void) {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            favoriteMetadataPlain(metadataLive) { error in
                if error == .success {
                    self.favoriteMetadataPlain(metadata, completion: completion)
                } else {
                    completion(error)
                }
            }
        } else {
            favoriteMetadataPlain(metadata, completion: completion)
        }
    }

    private func favoriteMetadataPlain(_ metadata: tableMetadata, completion: @escaping (_ error: NKError) -> Void) {

        let fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)!
        let favorite = !metadata.favorite
        let ocId = metadata.ocId

        NextcloudKit.shared.setFavorite(fileName: fileName, favorite: favorite) { account, error in
            if error == .success && metadata.account == account {
                NCManageDatabase.shared.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite)
#if !EXTENSION
                if favorite {
                    NCOperationQueue.shared.synchronizationMetadata(metadata, selector: NCGlobal.shared.selectorReadFile)
                }
#endif
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterFavoriteFile, userInfo: ["ocId": ocId, "serverUrl": metadata.serverUrl])
            }
            completion(error)
        }
    }

    func listingFavoritescompletion(selector: String, completion: @escaping (_ account: String, _ metadatas: [tableMetadata]?, _ error: NKError) -> Void) {
        
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.listingFavorites(showHiddenFiles: CCUtility.getShowHiddenFiles(), options: options) { account, files, data, error in
            guard error == .success else {
                completion(account, nil, error)
                return
            }

            NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, _, metadatas in
                NCManageDatabase.shared.updateMetadatasFavorite(account: account, metadatas: metadatas)
                if selector != NCGlobal.shared.selectorListingFavorite {
#if !EXTENSION
                    for metadata in metadatas {
                        NCOperationQueue.shared.synchronizationMetadata(metadata, selector: selector)
                    }
#endif
                }
                completion(account, metadatas, error)
            }
        }
    }

    // MARK: - Lock Files

    func lockUnlockFile(_ metadata: tableMetadata, shoulLock: Bool) {
        NextcloudKit.shared.lockUnlockFile(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName, shouldLock: shoulLock) { account, error in
            // 0: lock was successful; 412: lock did not change, no error, refresh
            guard error == .success || error.errorCode == NCGlobal.shared.errorPreconditionFailed else {
                let error = NKError(errorCode: error.errorCode, errorDescription: "_files_lock_error_")
                NCContentPresenter.shared.messageNotification(metadata.fileName, error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                return
            }
            NCNetworking.shared.readFile(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName) { account, metadata, error in
                guard error == .success, let metadata = metadata else { return }
                NCManageDatabase.shared.addMetadata(metadata)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
            }
        }
    }

    // MARK: - WebDav Rename

    func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, viewController: UIViewController?, completion: @escaping (_ error: NKError) -> Void) {

        let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        let fileNameNew = fileNameNew.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileNameNewLive = (fileNameNew as NSString).deletingPathExtension + ".mov"

        if metadata.isDirectoryE2EE {
#if !EXTENSION
            Task {
                if let metadataLive = metadataLive {
                    let error = await NCNetworkingE2EERename.shared.rename(metadata: metadataLive, fileNameNew: fileNameNew)
                    if error == .success {
                        let error = await NCNetworkingE2EERename.shared.rename(metadata: metadata, fileNameNew: fileNameNew)
                        DispatchQueue.main.async { completion(error) }
                    } else {
                        DispatchQueue.main.async { completion(error) }
                    }
                } else {
                    let error = await NCNetworkingE2EERename.shared.rename(metadata: metadata, fileNameNew: fileNameNew)
                    DispatchQueue.main.async { completion(error) }
                }
            }
#endif
        } else {
            if metadataLive == nil {
                renameMetadataPlain(metadata, fileNameNew: fileNameNew, completion: completion)
            } else {
                renameMetadataPlain(metadataLive!, fileNameNew: fileNameNewLive) { error in
                    if error == .success {
                        self.renameMetadataPlain(metadata, fileNameNew: fileNameNew, completion: completion)
                    } else {
                        completion(error)
                    }
                }
            }
        }
    }

    private func renameMetadataPlain(_ metadata: tableMetadata, fileNameNew: String, completion: @escaping (_ error: NKError) -> Void) {

        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !(metadata.permissions == "") && !permission {
            return completion(NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }
        guard let fileNameNew = CCUtility.removeForbiddenCharactersServer(fileNameNew) else {
            return completion(NKError())
        }
        if fileNameNew.count == 0 || fileNameNew == metadata.fileNameView {
            return completion(NKError())
        }

        let fileNamePath = metadata.serverUrl + "/" + metadata.fileName
        let fileNameToPath = metadata.serverUrl + "/" + fileNameNew
        let ocId = metadata.ocId

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false) { account, error in

            if error == .success {

                NCManageDatabase.shared.renameMetadata(fileNameTo: fileNameNew, ocId: ocId)

                if metadata.directory {

                    let serverUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
                    let serverUrlTo = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: fileNameNew)!
                    if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {

                        NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: serverUrlTo, etag: "", ocId: nil, fileId: nil, encrypted: directory.e2eEncrypted, richWorkspace: nil, account: metadata.account)
                    }

                } else {

                    let ext = (metadata.fileName as NSString).pathExtension
                    let extNew = (fileNameNew as NSString).pathExtension

                    if ext != extNew {

                        if let path = CCUtility.getDirectoryProviderStorageOcId(ocId) {
                            NCUtilityFileSystem.shared.deleteFile(filePath: path)
                        }
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced, userInfo: ["serverUrl": metadata.serverUrl])

                    } else {

                        NCManageDatabase.shared.setLocalFile(ocId: ocId, fileName: fileNameNew, etag: nil)
                        // Move file system
                        let atPath = CCUtility.getDirectoryProviderStorageOcId(ocId) + "/" + metadata.fileName
                        let toPath = CCUtility.getDirectoryProviderStorageOcId(ocId) + "/" + fileNameNew
                        do {
                            try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                        } catch { }
                    }
                }

                if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRenameFile, userInfo: ["ocId": metadata.ocId, "account": metadata.account])
                }
            }

            completion(error)
        }
    }

    // MARK: - WebDav Move

    @objc func moveMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ error: NKError) -> Void) {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            moveMetadataPlain(metadataLive, serverUrlTo: serverUrlTo, overwrite: overwrite) { error in
                if error == .success {
                    self.moveMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite, completion: completion)
                } else {
                    completion(error)
                }
            }
        } else {
            moveMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite, completion: completion)
        }
    }

    private func moveMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ error: NKError) -> Void) {

        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !(metadata.permissions == "") && !permission {
            return completion(NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }

        let serverUrlFrom = metadata.serverUrl
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite) { account, error in

            if error == .success {
                if metadata.directory {
                    NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: account)
                }
                NCManageDatabase.shared.moveMetadata(ocId: metadata.ocId, serverUrlTo: serverUrlTo)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMoveFile, userInfo: ["ocId": metadata.ocId, "account": metadata.account, "serverUrlFrom": serverUrlFrom])
            }

            completion(error)
        }
    }

    // MARK: - WebDav Copy

    func copyMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ error: NKError) -> Void) {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            copyMetadataPlain(metadataLive, serverUrlTo: serverUrlTo, overwrite: overwrite) { error in
                if error == .success {
                    self.copyMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite, completion: completion)
                } else {
                    completion(error)
                }
            }
        } else {
            copyMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite, completion: completion)
        }
    }

    private func copyMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ error: NKError) -> Void) {

        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !(metadata.permissions == "") && !permission {
            return completion(NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }

        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        NextcloudKit.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite) { _, error in

            if error == .success {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCopyFile, userInfo: ["ocId": metadata.ocId, "serverUrlTo": serverUrlTo])
            }
            completion(error)
        }
    }

    // MARK: - Direct Download

    func getVideoUrl(metadata: tableMetadata, completition: @escaping (_ url: URL?) -> Void) {

        if CCUtility.fileProviderStorageExists(metadata) {
            completition(URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)))
        } else {
            NextcloudKit.shared.getDirectDownload(fileId: metadata.fileId) { account, url, data, error in
                if error == .success && url != nil {
                    if let url = URL(string: url!) {
                        completition(url)
                    } else {
                        completition(nil)
                    }
                } else {
                    completition(nil)
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
