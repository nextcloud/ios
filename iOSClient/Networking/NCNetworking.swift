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
import NCCommunication
import Alamofire
import Queuer

@objc public protocol NCNetworkingDelegate {
    @objc optional func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Int64, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String)
}

@objc class NCNetworking: NSObject, NCCommunicationCommonDelegate {
    @objc public static let shared: NCNetworking = {
        let instance = NCNetworking()
        return instance
    }()

    weak var delegate: NCNetworkingDelegate?

    var lastReachability: Bool = true
    var networkReachability: NCCommunicationCommon.typeReachability?
    var downloadRequest: [String: DownloadRequest] = [:]
    var uploadRequest: [String: UploadRequest] = [:]
    var uploadMetadataInBackground: [String: tableMetadata] = [:]
    
    @objc public let sessionMaximumConnectionsPerHost = 5
    @objc public let sessionIdentifierBackground: String = "com.nextcloud.session.upload.background"
    @objc public let sessionIdentifierBackgroundWWan: String = "com.nextcloud.session.upload.backgroundWWan"
    @objc public let sessionIdentifierBackgroundExtension: String = "com.nextcloud.session.upload.extension"

    @objc public lazy var sessionManagerBackground: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifierBackground)
        configuration.allowsCellularAccess = true
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = sessionMaximumConnectionsPerHost
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: NCCommunicationBackground.shared, delegateQueue: OperationQueue.main)
        return session
    }()

    @objc public lazy var sessionManagerBackgroundWWan: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifierBackgroundWWan)
        configuration.allowsCellularAccess = false
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = sessionMaximumConnectionsPerHost
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: NCCommunicationBackground.shared, delegateQueue: OperationQueue.main)
        return session
    }()

    #if EXTENSION
    @objc public lazy var sessionManagerBackgroundExtension: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifierBackgroundExtension)
        configuration.allowsCellularAccess = true
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = sessionMaximumConnectionsPerHost
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        configuration.sharedContainerIdentifier = NCBrandOptions.shared.capabilitiesGroups
        let session = URLSession(configuration: configuration, delegate: NCCommunicationBackground.shared, delegateQueue: OperationQueue.main)
        return session
    }()
    #endif

    // MARK: - init

    override init() {
        super.init()

        #if EXTENSION
        _ = sessionIdentifierBackgroundExtension
        #else
        _ = sessionManagerBackground
        _ = sessionManagerBackgroundWWan
        #endif
    }

    // MARK: - Communication Delegate

    func networkReachabilityObserver(_ typeReachability: NCCommunicationCommon.typeReachability) {

        #if !EXTENSION
        if typeReachability == NCCommunicationCommon.typeReachability.reachableCellular || typeReachability == NCCommunicationCommon.typeReachability.reachableEthernetOrWiFi {

            if !lastReachability {
                NCService.shared.startRequestServicesServer()
            }
            lastReachability = true

        } else {

            if lastReachability {
                NCContentPresenter.shared.messageNotification("_network_not_available_", description: nil, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: -1009)
            }
            lastReachability = false
        }

        networkReachability = typeReachability
        #endif
    }

    func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if checkTrustedChallenge(session, didReceive: challenge) {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }

    func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.downloadProgress?(progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected, fileName: fileName, serverUrl: serverUrl, session: session, task: task)
    }

    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Int64, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String) {
        delegate?.downloadComplete?(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, description: description, task: task, errorCode: errorCode, errorDescription: errorDescription)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {

        #if !EXTENSION
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate, let completionHandler = appDelegate.backgroundSessionCompletionHandler {
            NCCommunicationCommon.shared.writeLog("Called urlSessionDidFinishEvents for Background URLSession")
            appDelegate.backgroundSessionCompletionHandler = nil
            completionHandler()
        }
        #endif
    }

    // MARK: - Pinning check

    private func checkTrustedChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) -> Bool {

        let protectionSpace: URLProtectionSpace = challenge.protectionSpace
        let directoryCertificate = CCUtility.getDirectoryCerificates()!
        let host = challenge.protectionSpace.host
        let certificateSavedPath = directoryCertificate + "/" + host + ".der"
        var isTrusted: Bool

        #if !EXTENSION
        defer {
            DispatchQueue.main.async {
                if !isTrusted {
                    (UIApplication.shared.delegate as? AppDelegate)?.trustCertificateError(host: host)
                }
            }
        }
        #endif
        
        print("SSL host: \(host)")
        
        if let serverTrust: SecTrust = protectionSpace.serverTrust, let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0)  {
            
            // extarct certificate txt
            saveX509Certificate(certificate, host: host, directoryCertificate: directoryCertificate)
           
            var secresult = SecTrustResultType.invalid
            let status = SecTrustEvaluate(serverTrust, &secresult)
            let isServerTrusted = SecTrustEvaluateWithError(serverTrust, nil)
            
            let certificateCopyData = SecCertificateCopyData(certificate)
            let data = CFDataGetBytePtr(certificateCopyData);
            let size = CFDataGetLength(certificateCopyData);
            let certificateData = NSData(bytes: data, length: size)
                
            certificateData.write(toFile: directoryCertificate + "/" + host + ".tmp", atomically: true)
            
            if isServerTrusted {
                isTrusted = true
            } else if status == errSecSuccess, let certificateDataSaved = NSData(contentsOfFile: certificateSavedPath), certificateData.isEqual(to: certificateDataSaved as Data) {
                isTrusted = true
            } else {
                isTrusted = false
            }
        } else {
            isTrusted = false
        }
        
        return isTrusted
    }

    func writeCertificate(host: String) {

        let directoryCertificate = CCUtility.getDirectoryCerificates()!
        let certificateAtPath = directoryCertificate + "/" + host + ".tmp"
        let certificateToPath = directoryCertificate + "/" + host + ".der"

        if !NCUtilityFileSystem.shared.moveFile(atPath: certificateAtPath, toPath: certificateToPath) {
            NCContentPresenter.shared.messageNotification("_error_", description: "_error_creation_file_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorCreationFile, priority: .max)
        }
    }
    
    private func saveX509Certificate(_ certificate: SecCertificate, host: String, directoryCertificate: String) {
        
        let certNamePathTXT = directoryCertificate + "/" + host + ".txt"
        let data: CFData = SecCertificateCopyData(certificate)
        let mem = BIO_new_mem_buf(CFDataGetBytePtr(data), Int32(CFDataGetLength(data)))
        let x509cert = d2i_X509_bio(mem, nil)

        if x509cert == nil {
            print("[LOG] OpenSSL couldn't parse X509 Certificate")
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

    func checkPushNotificationServerProxyCertificateUntrusted(viewController: UIViewController?, completion: @escaping (_ errorCode: Int) -> Void) {

        guard let host = URL(string: NCBrandOptions.shared.pushNotificationServerProxy)?.host else { return }

        NCCommunication.shared.checkServer(serverUrl: NCBrandOptions.shared.pushNotificationServerProxy) { errorCode, _ in

            if errorCode == 0 {

                NCNetworking.shared.writeCertificate(host: host)
                completion(errorCode)

            } else if errorCode == NSURLErrorServerCertificateUntrusted {

                let alertController = UIAlertController(title: NSLocalizedString("_ssl_certificate_untrusted_", comment: ""), message: NSLocalizedString("_connect_server_anyway_", comment: ""), preferredStyle: .alert)

                alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { _ in
                    NCNetworking.shared.writeCertificate(host: host)
                    completion(0)
                }))

                alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { _ in
                    completion(errorCode)
                }))

                alertController.addAction(UIAlertAction(title: NSLocalizedString("_certificate_details_", comment: ""), style: .default, handler: { _ in
                    if let navigationController = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil).instantiateInitialViewController() as? UINavigationController {
                        let vcCertificateDetails = navigationController.topViewController as! NCViewCertificateDetails
                        vcCertificateDetails.host = host
                        viewController?.present(navigationController, animated: true)
                    }
                }))

                viewController?.present(alertController, animated: true)

            } else {

                completion(0)
            }
        }
    }

    // MARK: - Utility

    func cancelTaskWithUrl(_ url: URL) {
        NCCommunication.shared.getSessionManager().getAllTasks { tasks in
            tasks.filter { $0.state == .running }.filter { $0.originalRequest?.url == url }.first?.cancel()
        }
    }

    @objc func cancelAllTask() {
        NCCommunication.shared.getSessionManager().getAllTasks { tasks in
            for task in tasks {
                task.cancel()
            }
        }
    }

    // MARK: - Download

    @objc func cancelDownload(ocId: String, serverUrl: String, fileNameView: String) {

        #if !EXTENSION
        // removed progress ocid
        DispatchQueue.main.async { (UIApplication.shared.delegate as! AppDelegate).listProgress[ocId] = nil }
        #endif

        guard let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView) else { return }

        if let request = downloadRequest[fileNameLocalPath] {
            request.cancel()
        } else {
            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {

                NCManageDatabase.shared.setMetadataSession(ocId: ocId, session: "", sessionError: "", sessionSelector: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile, userInfo: ["ocId": metadata.ocId])
            }
        }
    }
    
    @objc func download(metadata: tableMetadata, selector: String, notificationCenterProgressTask: Bool = true, progressHandler: @escaping (_ progress: Progress) -> () = { _ in }, completion: @escaping (_ errorCode: Int)->()) {
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!

        if NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) == nil {
            NCManageDatabase.shared.addMetadata(tableMetadata.init(value: metadata))
        }

        if metadata.status == NCGlobal.shared.metadataStatusInDownload || metadata.status == NCGlobal.shared.metadataStatusDownloading { return }

        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: NCCommunicationCommon.shared.sessionIdentifierDownload, sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusInDownload)

        NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, queue: NCCommunicationCommon.shared.backgroundQueue, requestHandler: { request in

            self.downloadRequest[fileNameLocalPath] = request

            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusDownloading)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadStartFile, userInfo: ["ocId":metadata.ocId])
            
        }, taskHandler: { (_) in
            
        }, progressHandler: { (progress) in
            
            if notificationCenterProgressTask {
                #if !EXTENSION
                // add progress ocid
                let progressType = NCGlobal.progressType(progress: Float(progress.fractionCompleted), totalBytes: progress.totalUnitCount, totalBytesExpected: progress.completedUnitCount)
                DispatchQueue.main.async { (UIApplication.shared.delegate as! AppDelegate).listProgress[metadata.ocId] = progressType }
                #endif
                
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterProgressTask, object: nil, userInfo: ["account":metadata.account, "ocId":metadata.ocId, "fileName":metadata.fileName, "serverUrl":metadata.serverUrl, "status":NSNumber(value: NCGlobal.shared.metadataStatusInDownload), "progress":NSNumber(value: progress.fractionCompleted), "totalBytes":NSNumber(value: progress.totalUnitCount), "totalBytesExpected":NSNumber(value: progress.completedUnitCount)])
            }
            
            progressHandler(progress)
                                        
        }) { (account, etag, date, length, allHeaderFields, error, errorCode, errorDescription) in
              
            if error?.isExplicitlyCancelledError ?? false {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal)

            } else if errorCode == 0 {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal, etag: etag)
                NCManageDatabase.shared.addLocalFile(metadata: metadata)

                #if !EXTENSION
                if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@", metadata.fileName, metadata.serverUrl)) {

                    NCEndToEndEncryption.sharedManager()?.decryptFileName(metadata.fileName, fileNameView: metadata.fileNameView, ocId: metadata.ocId, key: result.key, initializationVector: result.initializationVector, authenticationTag: result.authenticationTag)
                }
                CCUtility.setExif(metadata) { _, _, _, _, _ in }
                #endif

            } else {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: errorDescription, sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusDownloadError)

                #if !EXTENSION
                if errorCode == 401 || errorCode == 403 {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: metadata.account, errorCode: errorCode, errorDescription: errorDescription)
                }
                #endif
            }

            self.downloadRequest[fileNameLocalPath] = nil
            #if !EXTENSION
            DispatchQueue.main.async { (UIApplication.shared.delegate as! AppDelegate).listProgress[metadata.ocId] = nil }
            #endif

            if error?.isExplicitlyCancelledError ?? false {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile, userInfo: ["ocId": metadata.ocId])
            } else {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": selector, "errorCode": errorCode, "errorDescription": errorDescription])
            }

            completion(errorCode)
        }
    }

    // MARK: - Upload

    @objc func upload(metadata: tableMetadata, start: @escaping () -> Void, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {
        
        func uploadMetadata(_ metadata: tableMetadata) {
            
            NCManageDatabase.shared.addMetadata(metadata)
            let metadata = tableMetadata.init(value: metadata)
            
            if metadata.e2eEncrypted {
#if !EXTENSION_FILE_PROVIDER_EXTENSION
                NCNetworkingE2EE.shared.upload(metadata: metadata, start: start) { errorCode, errorDescription in
                    DispatchQueue.main.async {
                        completion(errorCode, errorDescription)
                    }
                }
#endif
            } else if metadata.chunk {
                uploadChunkedFile(metadata: metadata, start: start) { errorCode, errorDescription in
                    DispatchQueue.main.async {
                        completion(errorCode, errorDescription)
                    }
                }
            } else if metadata.session == NCCommunicationCommon.shared.sessionIdentifierUpload {
                uploadFile(metadata: metadata, start: start) { errorCode, errorDescription in
                    DispatchQueue.main.async {
                        completion(errorCode, errorDescription)
                    }
                }
            } else {
                uploadFileInBackground(metadata: metadata, start: start) { errorCode, errorDescription in
                    DispatchQueue.main.async {
                        completion(errorCode, errorDescription)
                    }
                }
            }
        }
        
        let metadata = tableMetadata.init(value: metadata)

        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {

            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            let results = NCCommunicationCommon.shared.getInternalType(fileName: metadata.fileNameView, mimeType: metadata.contentType, directory: false)
            metadata.contentType = results.mimeType
            metadata.iconName = results.iconName
            metadata.classFile = results.classFile
            if let date = NCUtilityFileSystem.shared.getFileCreationDate(filePath: fileNameLocalPath) {
                 metadata.creationDate = date
            }
            if let date =  NCUtilityFileSystem.shared.getFileModificationDate(filePath: fileNameLocalPath) {
                metadata.date = date
            }
            metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: fileNameLocalPath)

            uploadMetadata(metadata)

        } else {

            CCUtility.extractImageVideoFromAssetLocalIdentifier(forUpload: metadata, notification: true) { extractMetadata, fileNamePath in

                guard let metadata = extractMetadata else {
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    return completion(NCGlobal.shared.errorInternalError, "Internal error")
                }

                let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                NCUtilityFileSystem.shared.moveFileInBackground(atPath: fileNamePath!, toPath: fileNameLocalPath)

                uploadMetadata(metadata)
            }
        }
    }

    private func uploadFile(metadata: tableMetadata, start: @escaping () -> Void, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        var uploadTask: URLSessionTask?
        let description = metadata.ocId

        NCCommunication.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, customUserAgent: nil, addCustomHeaders: nil, requestHandler: { request in

            self.uploadRequest[fileNameLocalPath] = request

        }, taskHandler: { task in

            uploadTask = task
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId])
            start()

        }, progressHandler: { progress in

            #if !EXTENSION
            // add progress ocid
            let progressType = NCGlobal.progressType(progress: Float(progress.fractionCompleted), totalBytes: progress.totalUnitCount, totalBytesExpected: progress.completedUnitCount)
            DispatchQueue.main.async { (UIApplication.shared.delegate as! AppDelegate).listProgress[metadata.ocId] = progressType }
            #endif

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

        }) { _, ocId, etag, date, size, _, _, errorCode, errorDescription in

            self.uploadRequest[fileNameLocalPath] = nil
            self.uploadComplete(fileName: metadata.fileName, serverUrl: metadata.serverUrl, ocId: ocId, etag: etag, date: date, size: size, description: description, task: uploadTask!, errorCode: errorCode, errorDescription: errorDescription)

            completion(errorCode, errorDescription)
        }
    }

    private func uploadFileInBackground(metadata: tableMetadata, start: @escaping () -> Void, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

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
        if NCUtilityFileSystem.shared.getFileSize(filePath: fileNameLocalPath) == 0 {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

            completion(NCGlobal.shared.errorResourceNotFound, NSLocalizedString("_error_not_found_", value: "The requested resource could not be found", comment: ""))

        } else {

            if let task = NCCommunicationBackground.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, description: metadata.ocId, session: session!) {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading)

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId])

                completion(0, "")

            } else {

                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                completion(NCGlobal.shared.errorInternalError, "task null")
            }
        }
    }

    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String) {
        if delegate != nil {
            delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size: size, description: description, task: task, errorCode: errorCode, errorDescription: errorDescription)
        } else {

            guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(description) else { return }
            guard let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", metadata.account)) else { return }
            let ocIdTemp = metadata.ocId
            var errorDescription = errorDescription

            if errorCode == 0 && ocId != nil && size > 0 {

                let metadata = tableMetadata.init(value: metadata)

                NCUtilityFileSystem.shared.moveFileInBackground(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), toPath: CCUtility.getDirectoryProviderStorageOcId(ocId))

                metadata.uploadDate = date ?? NSDate()
                metadata.etag = etag ?? ""
                metadata.ocId = ocId!

                if let fileId = NCUtility.shared.ocIdToFileId(ocId: ocId) {
                    metadata.fileId = fileId
                }

                metadata.session = ""
                metadata.sessionError = ""
                metadata.sessionTaskIdentifier = 0
                metadata.status = NCGlobal.shared.metadataStatusNormal

                // Delete Asset on Photos album
                if tableAccount.autoUploadDeleteAssetLocalIdentifier && metadata.assetLocalIdentifier != "" && metadata.sessionSelector == NCGlobal.shared.selectorUploadAutoUpload {
                    metadata.deleteAssetLocalIdentifier = true
                }

                if CCUtility.getDisableLocalCacheAfterUpload() {
                    CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } else {
                    NCManageDatabase.shared.addLocalFile(metadata: metadata)
                }
                NCManageDatabase.shared.addMetadata(metadata)
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))

                #if !EXTENSION
                self.getOcIdInBackgroundSession { listOcId in
                    if listOcId.count == 0 && self.uploadRequest.count == 0 {
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        appDelegate.networkingProcessUpload?.startProcess()
                    }
                }
                CCUtility.setExif(metadata) { _, _, _, _, _ in }
                #endif

                NCCommunicationCommon.shared.writeLog("Upload complete " + serverUrl + "/" + fileName + ", result: success(\(size) bytes)")
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "ocIdTemp": ocIdTemp, "errorCode": errorCode, "errorDescription": ""])

            } else {

                if errorCode == NSURLErrorCancelled || errorCode == NCGlobal.shared.errorRequestExplicityCancelled {

                    CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])

                } else if errorCode == 401 || errorCode == 403 {

                    #if !EXTENSION
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: metadata.account, errorCode: errorCode, errorDescription: errorDescription)
                    #endif

                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)

                } else {

                    if size == 0 {
                        errorDescription = "File length 0"
                        NCCommunicationCommon.shared.writeLog("Upload error 0 length " + serverUrl + "/" + fileName + ", result: success(\(size) bytes)")
                    }

                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)
                }

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "ocIdTemp": ocIdTemp, "errorCode": errorCode, "errorDescription": ""])
            }

            #if !EXTENSION
            DispatchQueue.main.async { (UIApplication.shared.delegate as! AppDelegate).listProgress[metadata.ocId] = nil }
            #endif

            // Delete
            self.uploadMetadataInBackground[fileName+serverUrl] = nil
        }
    }

    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.uploadProgress?(progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected, fileName: fileName, serverUrl: serverUrl, session: session, task: task)

        var metadata: tableMetadata?
        let description: String = task.taskDescription ?? ""

        if let metadataTmp = self.uploadMetadataInBackground[fileName+serverUrl] {
            metadata = metadataTmp
        } else if let metadataTmp = NCManageDatabase.shared.getMetadataFromOcId(description) {
            self.uploadMetadataInBackground[fileName+serverUrl] = metadataTmp
            metadata = metadataTmp
        }

        if let metadata = metadata {

            #if !EXTENSION
            // add progress ocid
            let progressType = NCGlobal.progressType(progress: progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected)
            DispatchQueue.main.async { (UIApplication.shared.delegate as! AppDelegate).listProgress[metadata.ocId] = progressType }
            #endif

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

    func getOcIdInBackgroundSession(completion: @escaping (_ listOcId: [String]) -> Void) {

        var listOcId: [String] = []

        sessionManagerBackground.getAllTasks(completionHandler: { tasks in
            for task in tasks {
                listOcId.append(task.description)
            }
            self.sessionManagerBackgroundWWan.getAllTasks(completionHandler: { tasks in
                for task in tasks {
                    listOcId.append(task.description)
                }
                completion(listOcId)
            })
        })
    }

    // MARK: - Transfer (Download Upload)

    @objc func cancelTransferMetadata(_ metadata: tableMetadata, completion: @escaping () -> Void) {

        let metadata = tableMetadata.init(value: metadata)

        #if !EXTENSION
        // removed progress ocid
        DispatchQueue.main.async { (UIApplication.shared.delegate as! AppDelegate).listProgress[metadata.ocId] = nil }
        #endif

        if metadata.session.count == 0 {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            return completion()
        }

        if metadata.session == NCCommunicationCommon.shared.sessionIdentifierDownload {

            NCNetworking.shared.cancelDownload(ocId: metadata.ocId, serverUrl: metadata.serverUrl, fileNameView: metadata.fileNameView)
            return completion()
        }

        if metadata.session == NCCommunicationCommon.shared.sessionIdentifierUpload {

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

            if metadata.status == NCGlobal.shared.metadataStatusDownloading && metadata.session == NCCommunicationCommon.shared.sessionIdentifierDownload {
                cancelDownload(ocId: metadata.ocId, serverUrl: metadata.serverUrl, fileNameView: metadata.fileNameView)
            }
        }

        #if !EXTENSION
        NCOperationQueue.shared.downloadCancelAll()
        #endif
    }

    // MARK: - WebDav Read file, folder

    @objc func readFolder(serverUrl: String, account: String, completion: @escaping (_ account: String, _ metadataFolder: tableMetadata?, _ metadatas: [tableMetadata]?, _ metadatasUpdate: [tableMetadata]?, _ metadatasLocalUpdate: [tableMetadata]?, _ metadatasDelete: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String) -> Void) {

        NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: CCUtility.getShowHiddenFiles(), queue: NCCommunicationCommon.shared.backgroundQueue) { account, files, _, errorCode, errorDescription in

            if errorCode == 0 {

                NCManageDatabase.shared.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: true, account: account) { metadataFolder, metadatasFolder, metadatas in

                    // Add metadata folder
                    NCManageDatabase.shared.addMetadata(tableMetadata.init(value: metadataFolder))

                    // Update directory
                    NCManageDatabase.shared.addDirectory(encrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, serverUrl: serverUrl, account: metadataFolder.account)
                    NCManageDatabase.shared.setDirectory(richWorkspace: metadataFolder.richWorkspace, serverUrl: serverUrl, account: metadataFolder.account)

                    // Update sub directories NO Update richWorkspace
                    for metadata in metadatasFolder {
                        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                        NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, account: account)
                    }

                    let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, NCGlobal.shared.metadataStatusNormal))
                    let metadatasChanged = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareEtagLocal: true)

                    completion(account, metadataFolder, metadatas, metadatasChanged.metadatasUpdate, metadatasChanged.metadatasLocalUpdate, metadatasChanged.metadatasDelete, errorCode, "")
                }

            } else {

                completion(account, nil, nil, nil, nil, nil, errorCode, errorDescription)
            }
        }
    }

    @objc func readFile(serverUrlFileName: String, account: String, queue: DispatchQueue = NCCommunicationCommon.shared.backgroundQueue, completion: @escaping (_ account: String, _ metadata: tableMetadata?, _ errorCode: Int, _ errorDescription: String) -> Void) {

        NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles(), queue: queue) { account, files, _, errorCode, errorDescription in

            if errorCode == 0 && files.count == 1 {

                let file = files[0]
                let isEncrypted = CCUtility.isFolderEncrypted(file.serverUrl, e2eEncrypted: file.e2eEncrypted, account: account, urlBase: file.urlBase)
                let metadata = NCManageDatabase.shared.convertNCFileToMetadata(file, isEncrypted: isEncrypted, account: account)

                completion(account, metadata, errorCode, errorDescription)

            } else {

                completion(account, nil, errorCode, errorDescription)
            }
        }
    }

    // MARK: - WebDav Search

    @objc func searchFiles(urlBase: String, user: String, literal: String, completion: @escaping (_ account: String, _ metadatas: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String) -> Void) {

        NCCommunication.shared.searchLiteral(serverUrl: urlBase, depth: "infinity", literal: literal, showHiddenFiles: CCUtility.getShowHiddenFiles(), queue: NCCommunicationCommon.shared.backgroundQueue) { account, files, errorCode, errorDescription in

            if errorCode == 0 {

                NCManageDatabase.shared.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: false, account: account) { _, metadatasFolder, metadatas in

                    // Update sub directories
                    for metadata in metadatasFolder {
                        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                        NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, account: account)
                    }

                    NCManageDatabase.shared.addMetadatas(metadatas)

                    let metadatas = Array(metadatas.map { tableMetadata.init(value: $0) })

                    completion(account, metadatas, errorCode, errorDescription)
                }

            } else {

                completion(account, nil, errorCode, errorDescription)
            }
        }
    }

    // MARK: - WebDav Create Folder

    @objc func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, overwrite: Bool = false, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(serverUrl, e2eEncrypted: false, account: account, urlBase: urlBase)

        if isDirectoryEncrypted {
            #if !EXTENSION
            NCNetworkingE2EE.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, completion: completion)
            #endif
        } else {
            createFolderPlain(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, overwrite: overwrite, completion: completion)
        }
    }

    private func createFolderPlain(fileName: String, serverUrl: String, account: String, urlBase: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!

        if !overwrite {
            fileNameFolder = NCUtilityFileSystem.shared.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        }
        if fileNameFolder.count == 0 {
            return completion(0, "")
        }
        let fileNameFolderUrl = serverUrl + "/" + fileNameFolder

        NCCommunication.shared.createFolder(fileNameFolderUrl) { account, ocId, _, errorCode, errorDescription in

            if errorCode == 0 {

                self.readFile(serverUrlFileName: fileNameFolderUrl, account: account) { account, metadataFolder, errorCode, errorDescription in

                    if errorCode == 0 {

                        if let metadata = metadataFolder {

                            NCManageDatabase.shared.addMetadata(metadata)
                            NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: fileNameFolderUrl, account: account)
                        }

                        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadataFolder?.ocId) {
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": metadata.ocId])
                        }
                    }

                    completion(errorCode, errorDescription)
                }

            } else if errorCode == 405 && overwrite {

                completion(0, "")

            } else {

                completion(errorCode, errorDescription)
            }
        }
    }

    func createFolder(assets: [PHAsset], selector: String, useSubFolder: Bool, account: String, urlBase: String) -> Bool {

        let serverUrl = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: urlBase, account: account)
        let fileName =  NCManageDatabase.shared.getAccountAutoUploadFileName()
        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: urlBase, account: account)
        var result = createFolderWithSemaphore(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase)

        if useSubFolder && result {
            for dateSubFolder in CCUtility.createNameSubFolder(assets) {
                let fileName = (dateSubFolder as! NSString).lastPathComponent
                let serverUrl = ((autoUploadPath + "/" + (dateSubFolder as! String)) as NSString).deletingLastPathComponent
                result = createFolderWithSemaphore(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase)
                if !result { break }
            }
        }

        return result
    }

    private func createFolderWithSemaphore(fileName: String, serverUrl: String, account: String, urlBase: String) -> Bool {

        var result: Bool = false
        let semaphore = Semaphore()

        NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, overwrite: true) { errorCode, _ in
            if errorCode == 0 { result = true }
            semaphore.continue()
        }

        if semaphore.wait() == .success { result = true }
        return result
    }

    // MARK: - WebDav Delete

    @objc func deleteMetadata(_ metadata: tableMetadata, onlyLocalCache: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

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

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": metadata.ocId, "fileNameView": metadata.fileNameView, "classFile": metadata.classFile, "onlyLocalCache": true])
            }
            return completion(0, "")
        }

        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)

        if isDirectoryEncrypted {
            #if !EXTENSION
            if metadataLive == nil {
                NCNetworkingE2EE.shared.deleteMetadata(metadata, completion: completion)
            } else {
                NCNetworkingE2EE.shared.deleteMetadata(metadataLive!) { errorCode, errorDescription in
                    if errorCode == 0 {
                        NCNetworkingE2EE.shared.deleteMetadata(metadata, completion: completion)
                    } else {
                        completion(errorCode, errorDescription)
                    }
                }
            }
            #endif
        } else {
            if metadataLive == nil {
                self.deleteMetadataPlain(metadata, addCustomHeaders: nil, completion: completion)
            } else {
                self.deleteMetadataPlain(metadataLive!, addCustomHeaders: nil) { errorCode, errorDescription in
                    if errorCode == 0 {
                        self.deleteMetadataPlain(metadata, addCustomHeaders: nil, completion: completion)
                    } else {
                        completion(errorCode, errorDescription)
                    }
                }
            }
        }
    }

    func deleteMetadataPlain(_ metadata: tableMetadata, addCustomHeaders: [String: String]?, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

        // verify permission
        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanDelete)
        if metadata.permissions != "" && permission == false {
            return completion(NCGlobal.shared.errorInternalError, "_no_permission_delete_file_")
        }

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCCommunication.shared.deleteFileOrFolder(serverUrlFileName, customUserAgent: nil, addCustomHeaders: addCustomHeaders) { account, errorCode, errorDescription in

            if errorCode == 0 || errorCode == NCGlobal.shared.errorResourceNotFound {

                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }

                NCManageDatabase.shared.deleteVideo(metadata: metadata)
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

                if metadata.directory {
                    NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
                }

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": metadata.ocId, "fileNameView": metadata.fileNameView, "classFile": metadata.classFile, "onlyLocalCache": true])
            }

            completion(errorCode, errorDescription)
        }
    }

    // MARK: - WebDav Favorite

    @objc func favoriteMetadata(_ metadata: tableMetadata, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            favoriteMetadataPlain(metadataLive) { errorCode, errorDescription in
                if errorCode == 0 {
                    self.favoriteMetadataPlain(metadata, completion: completion)
                } else {
                    completion(errorCode, errorDescription)
                }
            }
        } else {
            favoriteMetadataPlain(metadata, completion: completion)
        }
    }

    private func favoriteMetadataPlain(_ metadata: tableMetadata, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

        let fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!
        let favorite = !metadata.favorite
        let ocId = metadata.ocId

        NCCommunication.shared.setFavorite(fileName: fileName, favorite: favorite) { account, errorCode, errorDescription in

            if errorCode == 0 && metadata.account == account {

                NCManageDatabase.shared.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite)

                #if !EXTENSION
                if favorite {
                    NCOperationQueue.shared.synchronizationMetadata(metadata, selector: NCGlobal.shared.selectorReadFile)
                }
                #endif

                if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterFavoriteFile, userInfo: ["ocId": metadata.ocId])
                }
            }

            completion(errorCode, errorDescription)
        }
    }

    @objc func listingFavoritescompletion(selector: String, completion: @escaping (_ account: String, _ metadatas: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String) -> Void) {
        NCCommunication.shared.listingFavorites(showHiddenFiles: CCUtility.getShowHiddenFiles(), queue: NCCommunicationCommon.shared.backgroundQueue) { account, files, errorCode, errorDescription in

            if errorCode == 0 {
                NCManageDatabase.shared.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: false, account: account) { _, _, metadatas in
                    NCManageDatabase.shared.updateMetadatasFavorite(account: account, metadatas: metadatas)
                    if selector != NCGlobal.shared.selectorListingFavorite {
                        #if !EXTENSION
                        for metadata in metadatas {
                            NCOperationQueue.shared.synchronizationMetadata(metadata, selector: selector)
                        }
                        #endif
                    }
                    completion(account, metadatas, errorCode, errorDescription)
                }
            } else {
                completion(account, nil, errorCode, errorDescription)
            }
        }
    }

    // MARK: - WebDav Rename

    @objc func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, viewController: UIViewController?, completion: @escaping (_ errorCode: Int, _ errorDescription: String?) -> Void) {

        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        let fileNameNewLive = (fileNameNew as NSString).deletingPathExtension + ".mov"

        if isDirectoryEncrypted {
            #if !EXTENSION
            if metadataLive == nil {
                NCNetworkingE2EE.shared.renameMetadata(metadata, fileNameNew: fileNameNew, completion: completion)
            } else {
                NCNetworkingE2EE.shared.renameMetadata(metadataLive!, fileNameNew: fileNameNewLive) { errorCode, errorDescription in
                    if errorCode == 0 {
                        NCNetworkingE2EE.shared.renameMetadata(metadata, fileNameNew: fileNameNew, completion: completion)
                    } else {
                        completion(errorCode, errorDescription)
                    }
                }
            }
            #endif
        } else {
            if metadataLive == nil {
                renameMetadataPlain(metadata, fileNameNew: fileNameNew, completion: completion)
            } else {
                renameMetadataPlain(metadataLive!, fileNameNew: fileNameNewLive) { errorCode, errorDescription in
                    if errorCode == 0 {
                        self.renameMetadataPlain(metadata, fileNameNew: fileNameNew, completion: completion)
                    } else {
                        completion(errorCode, errorDescription)
                    }
                }
            }
        }
    }

    private func renameMetadataPlain(_ metadata: tableMetadata, fileNameNew: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?) -> Void) {

        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !(metadata.permissions == "") && !permission {
            return completion(NCGlobal.shared.errorInternalError, "_no_permission_modify_file_")
        }
        guard let fileNameNew = CCUtility.removeForbiddenCharactersServer(fileNameNew) else {
            return completion(0, "")
        }
        if fileNameNew.count == 0 || fileNameNew == metadata.fileNameView {
            return completion(0, "")
        }

        let fileNamePath = metadata.serverUrl + "/" + metadata.fileName
        let fileNameToPath = metadata.serverUrl + "/" + fileNameNew
        let ocId = metadata.ocId

        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false) { account, errorCode, errorDescription in

            if errorCode == 0 {

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
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRenameFile, userInfo: ["ocId": metadata.ocId])
                }
            }

            completion(errorCode, errorDescription)
        }
    }

    // MARK: - WebDav Move

    @objc func moveMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?) -> Void) {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            moveMetadataPlain(metadataLive, serverUrlTo: serverUrlTo, overwrite: overwrite) { errorCode, errorDescription in
                if errorCode == 0 {
                    self.moveMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite, completion: completion)
                } else {
                    completion(errorCode, errorDescription)
                }
            }
        } else {
            moveMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite, completion: completion)
        }
    }

    private func moveMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?) -> Void) {

        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !(metadata.permissions == "") && !permission {
            return completion(NCGlobal.shared.errorInternalError, "_no_permission_modify_file_")
        }

        let serverUrlFrom = metadata.serverUrl
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite) { account, errorCode, errorDescription in

            if errorCode == 0 {

                if metadata.directory {
                    NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: account)
                }

                NCManageDatabase.shared.moveMetadata(ocId: metadata.ocId, serverUrlTo: serverUrlTo)

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMoveFile, userInfo: ["ocId": metadata.ocId, "serverUrlFrom": serverUrlFrom])
            }

            completion(errorCode, errorDescription)
        }
    }

    // MARK: - WebDav Copy

    @objc func copyMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?) -> Void) {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            copyMetadataPlain(metadataLive, serverUrlTo: serverUrlTo, overwrite: overwrite) { errorCode, errorDescription in
                if errorCode == 0 {
                    self.copyMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite, completion: completion)
                } else {
                    completion(errorCode, errorDescription)
                }
            }
        } else {
            copyMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite, completion: completion)
        }
    }

    private func copyMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?) -> Void) {

        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !(metadata.permissions == "") && !permission {
            return completion(NCGlobal.shared.errorInternalError, "_no_permission_modify_file_")
        }

        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        NCCommunication.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite) { _, errorCode, errorDescription in

            if errorCode == 0 {

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCopyFile, userInfo: ["ocId": metadata.ocId, "serverUrlTo": serverUrlTo])
            }

            completion(errorCode, errorDescription)
        }
    }

    // MARK: - Direct Download

    func getVideoUrl(metadata: tableMetadata, completition: @escaping (_ url: URL?) -> Void) {

        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {

            completition(URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)))

        } else {

            NCCommunication.shared.getDirectDownload(fileId: metadata.fileId) { _, url, errorCode, _ in

                if errorCode == 0 && url != nil {
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

    // MARK: - TEST API

    /*
    @objc public func getDirectDownload(urlBase: String, username: String, password: String, fileId: String, customUserAgent: String? = nil, completionHandler: @escaping (_ token: String?, _ errorCode: Int, _ errorDescription: String) -> Void) {
                
        let endpoint = "/ocs/v2.php/apps/dav/api/v1/direct"
        
        let url:URLConvertible = try! (urlBase + endpoint).asURL() as URLConvertible
        var headers: HTTPHeaders = [.authorization(username: username, password: password)]
        if customUserAgent != nil {
            headers.update(.userAgent(customUserAgent!))
        }
        //headers.update(.contentType("application/json"))
        headers.update(name: "OCS-APIRequest", value: "true")
               
        let method = HTTPMethod(rawValue: "POST")

        let parameters = [
            "fileId": fileId,
        ]
        
        AF.request(url, method: method, parameters: parameters, headers: headers).validate(statusCode: 200..<300).response { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                completionHandler(nil, 0, "")
            case .success(let data):
                if let data = data {
                    completionHandler("", 0, "")
                } else {
                    completionHandler(nil, NSURLErrorBadServerResponse, NSLocalizedString("_error_decode_xml_", value: "Invalid response, error decode XML", comment: ""))
                }
            }
        }
    }
    */
}
