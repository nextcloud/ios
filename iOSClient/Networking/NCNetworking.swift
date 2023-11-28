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

    public struct TransferInForegorund {
        var ocId: String
        var progress: Float
    }

    weak var delegate: NCNetworkingDelegate?
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    var lastReachability: Bool = true
    var networkReachability: NKCommon.TypeReachability?
    let downloadRequest = ThreadSafeDictionary<String, DownloadRequest>()
    let uploadRequest = ThreadSafeDictionary<String, UploadRequest>()
    let uploadMetadataInBackground = ThreadSafeDictionary<String, tableMetadata>()
    var transferInForegorund: TransferInForegorund?

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

    // MARK: - Download

    func download(metadata: tableMetadata, selector: String, notificationCenterProgressTask: Bool = true, checkfileProviderStorageExists: Bool = false,
                  requestHandler: @escaping (_ request: DownloadRequest) -> Void = { _ in },
                  progressHandler: @escaping (_ progress: Progress) -> Void = { _ in },
                  completion: @escaping (_ afError: AFError?, _ error: NKError) -> Void) {

        guard !metadata.isInTransfer else { return completion(nil, NKError()) }
        if checkfileProviderStorageExists, utilityFileSystem.fileProviderStorageExists(metadata) {
            return completion(nil, NKError())
        }

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        if NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) == nil {
            NCManageDatabase.shared.addMetadata(tableMetadata.init(value: metadata))
        }

        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload, sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusInDownload, errorCode: nil)

        NextcloudKit.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, options: options, requestHandler: { request in

            requestHandler(request)

            self.downloadRequest[fileNameLocalPath] = request

            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: nil, status: NCGlobal.shared.metadataStatusDownloading, errorCode: nil)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadStartFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])

        }, taskHandler: { _ in

        }, progressHandler: { progress in

            if notificationCenterProgressTask {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterProgressTask, object: nil, userInfo: ["account": metadata.account, "ocId": metadata.ocId, "fileName": metadata.fileName, "serverUrl": metadata.serverUrl, "status": NSNumber(value: NCGlobal.shared.metadataStatusInDownload), "progress": NSNumber(value: progress.fractionCompleted), "totalBytes": NSNumber(value: progress.totalUnitCount), "totalBytesExpected": NSNumber(value: progress.completedUnitCount)])
            }
            progressHandler(progress)

        }) { _, etag, _, _, _, afError, error in

            self.downloadRequest.removeValue(forKey: fileNameLocalPath)

            var sessionTaskFailedCode = 0
            if let error = NextcloudKit.shared.nkCommonInstance.getSessionErrorFromAFError(afError) {
                sessionTaskFailedCode = error.code
            }

            if afError?.isExplicitlyCancelledError ?? false || sessionTaskFailedCode == NCGlobal.shared.errorExplicitlyCancelled {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal, errorCode: 0)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])

            } else if error == .success {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal, etag: etag, errorCode: 0)
                NCManageDatabase.shared.addLocalFile(metadata: metadata)
#if !EXTENSION
                if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@", metadata.fileName, metadata.serverUrl)) {
                    NCEndToEndEncryption.sharedManager()?.decryptFile(metadata.fileName, fileNameView: metadata.fileNameView, ocId: metadata.ocId, key: result.key, initializationVector: result.initializationVector, authenticationTag: result.authenticationTag)
                }
#endif
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "selector": selector, "error": error])

            } else {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: error.errorDescription, sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusDownloadError, errorCode: error.errorCode)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "selector": selector, "error": error])
            }

            DispatchQueue.main.async { completion(afError, error) }
        }
    }

#if !EXTENSION
    func downloadAvatar(user: String, dispalyName: String?, fileName: String, cell: NCCellProtocol, view: UIView?, cellImageView: UIImageView?) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let fileNameLocalPath = utilityFileSystem.directoryUserData + "/" + fileName

        if let image = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) {
            cellImageView?.image = image
            cell.fileAvatarImageView?.image = image
            return
        }

        if let account = NCManageDatabase.shared.getActiveAccount() {
            cellImageView?.image = utility.loadUserImage(for: user, displayName: dispalyName, userBaseUrl: account)
        }

        for case let operation as NCOperationDownloadAvatar in appDelegate.downloadAvatarQueue.operations where operation.fileName == fileName { return }
        appDelegate.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: user, fileName: fileName, fileNameLocalPath: fileNameLocalPath, cell: cell, view: view, cellImageView: cellImageView))
    }
#endif

    // MARK: - Upload

    func upload(metadata: tableMetadata,
                uploadE2EEDelegate: uploadE2EEDelegate? = nil,
                hudView: UIView?,
                start: @escaping () -> Void = { },
                progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                completion: @escaping (_ error: NKError) -> Void = { _ in }) {

        let hud = JGProgressHUD()
        let metadata = tableMetadata.init(value: metadata)
        var numChunks: Int = 0
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload file \(metadata.fileNameView) with Identifier \(metadata.assetLocalIdentifier) with size \(metadata.size) [CHUNK \(metadata.chunk), E2EE \(metadata.isDirectoryE2EE)]")

        if metadata.isDirectoryE2EE {
#if !EXTENSION_FILE_PROVIDER_EXTENSION && !EXTENSION_WIDGET
            Task {
                let error = await NCNetworkingE2EEUpload().upload(metadata: metadata, uploadE2EEDelegate: uploadE2EEDelegate, hudView: hudView)
                completion(error)
            }
#endif
        } else if metadata.chunk > 0 {
                if let hudView {
                    DispatchQueue.main.async {
                        hud.indicatorView = JGProgressHUDRingIndicatorView()
                        if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
                            indicatorView.ringWidth = 1.5
                        }
                        hud.tapOnHUDViewBlock = { _ in
                            NotificationCenter.default.postOnMainThread(name: "NextcloudKit.chunkedFile.stop")
                        }
                        hud.textLabel.text = NSLocalizedString("_wait_file_preparation_", comment: "")
                        hud.detailTextLabel.text = NSLocalizedString("_tap_to_cancel_", comment: "")
                        hud.show(in: hudView)
                    }
                }
            uploadChunkFile(metadata: metadata) { num in
                numChunks = num
            } counterChunk: { counter in
                DispatchQueue.main.async { hud.progress = Float(counter) / Float(numChunks) }
            } start: {
                DispatchQueue.main.async { hud.dismiss() }
            } completion: { _, _, _, error in
                DispatchQueue.main.async { hud.dismiss() }
                completion(error)
            }
        } else if metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload {
            let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
            uploadFile(metadata: metadata, fileNameLocalPath: fileNameLocalPath, start: start, progressHandler: progressHandler) { _, _, _, _, _, _, _, error in
                completion(error)
            }
        } else {
            uploadFileInBackground(metadata: metadata, start: start) { error in
                completion(error)
            }
        }
    }

    func uploadFile(metadata: tableMetadata,
                    fileNameLocalPath: String,
                    withUploadComplete: Bool = true,
                    customHeaders: [String: String]? = nil,
                    start: @escaping () -> Void = { },
                    progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                    completion: @escaping (_ account: String, _ ocId: String?, _ etag: String?, _ date: NSDate?, _ size: Int64, _ allHeaderFields: [AnyHashable: Any]?, _ afError: AFError?, _ error: NKError) -> Void) {

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        var uploadTask: URLSessionTask?
        let description = metadata.ocId
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, options: options, requestHandler: { request in

            self.uploadRequest[fileNameLocalPath] = request

        }, taskHandler: { task in

            uploadTask = task
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading, errorCode: nil)
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

    func uploadChunkFile(metadata: tableMetadata,
                         withUploadComplete: Bool = true,
                         customHeaders: [String: String]? = nil,
                         numChunks: @escaping (_ num: Int) -> Void = { _ in },
                         counterChunk: @escaping (_ counter: Int) -> Void = { _ in },
                         start: @escaping () -> Void = { },
                         progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                         completion: @escaping (_ account: String, _ file: NKFile?, _ afError: AFError?, _ error: NKError) -> Void) {

        let directory = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId)
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
        let chunkFolder = NCManageDatabase.shared.getChunkFolder(account: metadata.account, ocId: metadata.ocId)
        let filesChunk = NCManageDatabase.shared.getChunks(account: metadata.account, ocId: metadata.ocId)
        var uploadTask: URLSessionTask?

        var chunkSize = NCGlobal.shared.chunkSizeMBCellular
        if NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
            chunkSize = NCGlobal.shared.chunkSizeMBEthernetOrWiFi
        }
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.uploadChunk(directory: directory, fileName: metadata.fileName, date: metadata.date as Date, creationDate: metadata.creationDate as Date, serverUrl: metadata.serverUrl, chunkFolder: chunkFolder, filesChunk: filesChunk, chunkSize: chunkSize, options: options) { num in

            numChunks(num)

        } counterChunk: { counter in

            counterChunk(counter)

        } start: { filesChunk in

            start()
            NCManageDatabase.shared.addChunks(account: metadata.account, ocId: metadata.ocId, chunkFolder: chunkFolder, filesChunk: filesChunk)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "sessionSelector": metadata.sessionSelector])

        } requestHandler: { request in

            self.uploadRequest[fileNameLocalPath] = request

        } taskHandler: { task in

            uploadTask = task
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading, errorCode: nil)

        } progressHandler: { totalBytesExpected, totalBytes, fractionCompleted in

            NotificationCenter.default.postOnMainThread(
                name: NCGlobal.shared.notificationCenterProgressTask,
                object: nil,
                userInfo: [
                    "account": metadata.account,
                    "ocId": metadata.ocId,
                    "fileName": metadata.fileName,
                    "serverUrl": metadata.serverUrl,
                    "status": NSNumber(value: NCGlobal.shared.metadataStatusInUpload),
                    "chunk": metadata.chunk,
                    "e2eEncrypted": metadata.e2eEncrypted,
                    "progress": NSNumber(value: fractionCompleted),
                    "totalBytes": NSNumber(value: totalBytes),
                    "totalBytesExpected": NSNumber(value: totalBytesExpected)])

            progressHandler(totalBytesExpected, totalBytes, fractionCompleted)

        } uploaded: { fileChunk in

            NCManageDatabase.shared.deleteChunk(account: metadata.account, ocId: metadata.ocId, fileChunk: fileChunk, directory: directory)

        } completion: { account, _, file, afError, error in

            var sessionTaskFailedCode = 0
            self.uploadRequest.removeValue(forKey: fileNameLocalPath)

            if error == .success {
                NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
            }
            if let error = NextcloudKit.shared.nkCommonInstance.getSessionErrorFromAFError(afError) {
                sessionTaskFailedCode = error.code
            }

            switch error.errorCode {
            case NKError.chunkNoEnoughMemory:
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                NCContentPresenter().messageNotification("_chunk_enough_memory_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
            case NKError.chunkCreateFolder:
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                NCContentPresenter().messageNotification("_chunk_create_folder_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
            case NKError.chunkFilesNull:
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                NCContentPresenter().messageNotification("_chunk_files_null_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
            case NKError.chunkFileNull:
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                NCContentPresenter().messageNotification("_chunk_file_null_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
            case NKError.chunkFileUpload:
                if let afError, (afError.isExplicitlyCancelledError || sessionTaskFailedCode == NCGlobal.shared.errorExplicitlyCancelled ) {
                    NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                }
            case NKError.chunkMoveFile:
                NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                NCContentPresenter().messageNotification("_chunk_move_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
            default: break
            }

            if withUploadComplete, let uploadTask {
                self.uploadComplete(fileName: metadata.fileName, serverUrl: metadata.serverUrl, ocId: file?.ocId, etag: file?.etag, date: file?.date, size: file?.size ?? 0, description: metadata.ocId, task: uploadTask, error: error)
            }

            completion(account, file, afError, error)
        }
    }

    private func uploadFileInBackground(metadata: tableMetadata,
                                        start: @escaping () -> Void = { },
                                        completion: @escaping (_ error: NKError) -> Void) {

        var session: URLSession?
        let metadata = tableMetadata.init(value: metadata)
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

        if metadata.session == sessionIdentifierBackground || metadata.session == sessionIdentifierBackgroundExtension {
            session = sessionManagerBackground
        } else if metadata.session == sessionIdentifierBackgroundWWan {
            session = sessionManagerBackgroundWWan
        }

        start()

        // Check file dim > 0
        if utilityFileSystem.getFileSize(filePath: fileNameLocalPath) == 0 && metadata.size != 0 {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            completion(NKError(errorCode: NCGlobal.shared.errorResourceNotFound, errorDescription: NSLocalizedString("_error_not_found_", value: "The requested resource could not be found", comment: "")))

        } else {

            if let task = nkBackground.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, description: metadata.ocId, session: session!) {

                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload file \(metadata.fileNameView) with task with taskIdentifier \(task.taskIdentifier)")

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading, errorCode: nil)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "sessionSelector": metadata.sessionSelector])
                completion(NKError())

            } else {

                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                completion(NKError(errorCode: NCGlobal.shared.errorResourceNotFound, errorDescription: "task null"))
            }
        }
    }

    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, error: NKError) {

        guard self.delegate == nil, let metadata = NCManageDatabase.shared.getMetadataFromOcId(description) else {
            self.delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size: size, description: description, task: task, error: error)
            return
        }
        let ocIdTemp = metadata.ocId
        let selector = metadata.sessionSelector
        var isApplicationStateActive = false
#if !EXTENSION
        isApplicationStateActive = UIApplication.shared.applicationState == .active
#endif

        if error == .success, let ocId = ocId, size == metadata.size {

            let metadata = tableMetadata.init(value: metadata)

            metadata.uploadDate = date ?? NSDate()
            metadata.etag = etag ?? ""
            metadata.ocId = ocId
            metadata.chunk = 0

            if let fileId = utility.ocIdToFileId(ocId: ocId) {
                metadata.fileId = fileId
            }

            metadata.session = ""
            metadata.sessionError = ""
            metadata.sessionTaskIdentifier = 0
            metadata.status = NCGlobal.shared.metadataStatusNormal

            // Delete Asset on Photos album
            if NCKeychain().removePhotoCameraRoll, !metadata.assetLocalIdentifier.isEmpty {
                metadata.deleteAssetLocalIdentifier = true
            }

            NCManageDatabase.shared.addMetadata(metadata)
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))

            if selector == NCGlobal.shared.selectorUploadFileNODelete {
                utilityFileSystem.moveFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTemp), toPath: utilityFileSystem.getDirectoryProviderStorageOcId(ocId))
                NCManageDatabase.shared.addLocalFile(metadata: metadata)
            } else {
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTemp))
            }

            setLivephotoUpload(metadata: metadata)

            NextcloudKit.shared.nkCommonInstance.writeLog("[SUCCESS] Upload complete " + serverUrl + "/" + fileName + ", result: success(\(size) bytes)")
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": error])

        } else {

            if error.errorCode == NSURLErrorCancelled || error.errorCode == NCGlobal.shared.errorRequestExplicityCancelled {

                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])

            } else if error.errorCode == NCGlobal.shared.errorForbidden && isApplicationStateActive {
#if !EXTENSION
                DispatchQueue.main.async {
                    let newFileName = self.utilityFileSystem.createFileName(metadata.fileName, serverUrl: metadata.serverUrl, account: metadata.account)
                    let alertController = UIAlertController(title: error.errorDescription, message: NSLocalizedString("_change_upload_filename_", comment: ""), preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: String(format: NSLocalizedString("_save_file_as_", comment: ""), newFileName), style: .default, handler: { _ in
                        let atpath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                        let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + newFileName
                        self.utilityFileSystem.moveFile(atPath: atpath, toPath: toPath)
                        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, newFileName: newFileName, session: nil, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusWaitUpload, errorCode: error.errorCode)
                    }))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive, handler: { _ in
                        self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                        NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])
                    }))

                    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
                    appDelegate.window?.rootViewController?.present(alertController, animated: true)
                }
#endif
            } else {

                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: error.errorDescription, sessionSelector: nil, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError, errorCode: error.errorCode)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": error])
            }
        }

        // Update Badge
        let counterBadgeDownload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status < 0"))
        let counterBadgeUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status > 0"))
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUpdateBadgeNumber, userInfo: ["counterDownload": counterBadgeDownload.count, "counterUpload": counterBadgeUpload.count])

        self.uploadMetadataInBackground.removeValue(forKey: fileName + serverUrl)
        self.delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size: size, description: description, task: task, error: error)
    }

    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
        DispatchQueue.global().async {
            self.delegate?.uploadProgress?(progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected, fileName: fileName, serverUrl: serverUrl, session: session, task: task)

            var metadata: tableMetadata?
            let description: String = task.taskDescription ?? ""

            if let metadataTmp = self.uploadMetadataInBackground[fileName + serverUrl] {
                metadata = metadataTmp
            } else if let metadataTmp = NCManageDatabase.shared.getMetadataFromOcId(description) {
                self.uploadMetadataInBackground[fileName + serverUrl] = metadataTmp
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
                        "chunk": metadata.chunk,
                        "e2eEncrypted": metadata.e2eEncrypted,
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

    // MARK: - Live Photo

    func setLivephotoUpload(metadata: tableMetadata) {

        guard NCGlobal.shared.capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion28,
              metadata.livePhoto,
              let metadata1 = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND urlBase == %@ AND path == %@ AND fileName == %@ AND status == %d", metadata.account, metadata.urlBase, metadata.path, metadata.livePhotoFile, NCGlobal.shared.metadataStatusNormal)) else {
            return
        }

        let serverUrlfileNamePath = metadata.urlBase + metadata.path + metadata.livePhotoFile
        let serverUrlfileNamePath1 = metadata1.urlBase + metadata1.path + metadata1.livePhotoFile

        Task {
            let results = await NextcloudKit.shared.setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath, livePhotoFile: metadata1.livePhotoFile)
            print("Send LivePhoto metadata error \(results.error.errorCode)")

            let results1 = await NextcloudKit.shared.setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath1, livePhotoFile: metadata.livePhotoFile)
            print("Send LivePhoto metadata1 error \(results1.error.errorCode)")
        }
    }

    func setLivePhoto(metadata: tableMetadata) {

        guard NCGlobal.shared.capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion28 else { return }

        Task {
            let serverUrlfileNamePath = metadata.urlBase + metadata.path + metadata.fileName
            let results = await NextcloudKit.shared.setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath, livePhotoFile: metadata.livePhotoFile)
            print("Send LivePhoto metadata error \(results.error.errorCode)")
        }
    }

    // MARK: - Cancel (Download Upload)

    // sessionIdentifierDownload: String = "com.nextcloud.nextcloudkit.session.download"
    // sessionIdentifierUpload: String = "com.nextcloud.nextcloudkit.session.upload"

    // sessionIdentifierBackground: String = "com.nextcloud.session.upload.background"
    // sessionIdentifierBackgroundWWan: String = "com.nextcloud.session.upload.backgroundWWan"
    // sessionIdentifierBackgroundExtension: String = "com.nextcloud.session.upload.extension"

    func cancelDataTask() {
#if !EXTENSION
        (UIApplication.shared.delegate as? AppDelegate)?.cancelAllQueue()
#endif
        let sessionManager = NextcloudKit.shared.sessionManager
        sessionManager.session.getTasksWithCompletionHandler { dataTasks, _, _ in
            dataTasks.forEach {
                $0.cancel()
            }
        }
    }

    func cancelDownloadTasks() {

        downloadRequest.removeAll()
        let sessionManager = NextcloudKit.shared.sessionManager
        sessionManager.session.getTasksWithCompletionHandler { _, _, downloadTasks in
            downloadTasks.forEach {
                $0.cancel()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let metadatasDownload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status < 0"))
            for metadata in metadatasDownload {
                self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal, errorCode: 0)
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
            let metadatasUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status > 0 AND session == %@", NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload))
            for metadata in metadatasUpload {
                self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            }
        }
    }

    func cancelUploadBackgroundTask() {

        Task {
            let tasksBackground = await NCNetworking.shared.sessionManagerBackground.tasks
            for task in tasksBackground.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                task.cancel()
            }
            let tasksBackgroundWWan = await NCNetworking.shared.sessionManagerBackgroundWWan.tasks
            for task in tasksBackgroundWWan.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                task.cancel()
            }
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let metadatasUploadBackground = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status > 0 AND (session == %@ || session == %@)", NCNetworking.shared.sessionIdentifierBackground, NCNetworking.shared.sessionIdentifierBackgroundWWan))
            for metadata in metadatasUploadBackground {
                self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal, errorCode: 0)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])
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
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])
            return
        }

        // UPLOAD BACKGROUND
        var session: URLSession?
        if metadata.session == NCNetworking.shared.sessionIdentifierBackground {
            session = NCNetworking.shared.sessionManagerBackground
        } else if metadata.session == NCNetworking.shared.sessionIdentifierBackgroundWWan {
            session = NCNetworking.shared.sessionManagerBackgroundWWan
        }
        if let tasks = await session?.tasks {
            for task in tasks.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                if task.taskIdentifier == metadata.sessionTaskIdentifier {
                    task.cancel()
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])
                }
            }
        }
    }

    // MARK: - WebDav Read file, folder

    func readFolder(serverUrl: String, account: String, completion: @escaping (_ account: String, _ metadataFolder: tableMetadata?, _ metadatas: [tableMetadata]?, _ metadatasUpdate: [tableMetadata]?, _ metadatasLocalUpdate: [tableMetadata]?, _ metadatasDelete: [tableMetadata]?, _ error: NKError) -> Void) {

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl,
                                             depth: "1",
                                             showHiddenFiles: NCKeychain().showHiddenFiles,
                                             includeHiddenFiles: NCGlobal.shared.includeHiddenFiles,
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, files, _, error in

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

    func readFile(serverUrlFileName: String, showHiddenFiles: Bool = NCKeychain().showHiddenFiles, queue: DispatchQueue = NextcloudKit.shared.nkCommonInstance.backgroundQueue, completion: @escaping (_ account: String, _ metadata: tableMetadata?, _ error: NKError) -> Void) {

        let options = NKRequestOptions(queue: queue)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, options: options) { account, files, _, error in
            guard error == .success, files.count == 1, let file = files.first else {
                completion(account, nil, error)
                return
            }

            let isDirectoryE2EE = self.utilityFileSystem.isDirectoryE2EE(file: file)
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

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName,
                                             depth: "0",
                                             requestBody: requestBody.data(using: .utf8),
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, files, _, error in

            if error == .success, let file = files.first {
                completion(account, true, file, error)
            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                completion(account, false, nil, error)
            } else {
                completion(account, nil, nil, error)
            }
        }
    }

    // MARK: - Synchronization ServerUrl

    func synchronizationServerUrl(_ serverUrl: String, account: String, selector: String) {

#if !EXTENSION
        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl,
                                             depth: "infinity",
                                             showHiddenFiles: NCKeychain().showHiddenFiles,
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, files, _, error in

            if error == .success {
                NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: true) { metadataFolder, _, metadatas in
                    NCManageDatabase.shared.addDirectory(encrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, serverUrl: metadataFolder.serverUrl + "/" + metadataFolder.fileName, account: metadataFolder.account)
                    let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND status == %d", account, serverUrl, NCGlobal.shared.metadataStatusNormal))
                    NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult)
                    for metadata in metadatas {
                        if metadata.directory {
                            let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                            NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: metadata.etag, permissions: metadata.permissions, serverUrl: serverUrl, account: metadata.account)
                        } else if selector == NCGlobal.shared.selectorSynchronizationOffline,
                                  self.synchronizeMetadata(metadata),
                                  let appDelegate = (UIApplication.shared.delegate as? AppDelegate),
                                  appDelegate.downloadQueue.operations.filter({ ($0 as? NCOperationDownload)?.metadata.ocId == metadata.ocId }).isEmpty {
                            appDelegate.downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: selector))
                        }
                    }
                }
            }
        }
#endif
    }

    func synchronizeMetadata(_ metadata: tableMetadata) -> Bool {

        let localFile = NCManageDatabase.shared.getResultsTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))?.first
        if localFile?.etag != metadata.etag || utilityFileSystem.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) == 0 {
            return true
        }
        return false
    }

    // MARK: - Search

    /// WebDAV search
    func searchFiles(urlBase: NCUserBaseUrl, literal: String, completion: @escaping (_ metadatas: [tableMetadata]?, _ error: NKError) -> Void) {

        NextcloudKit.shared.searchLiteral(serverUrl: urlBase.urlBase,
                                          depth: "infinity",
                                          literal: literal,
                                          showHiddenFiles: NCKeychain().showHiddenFiles,
                                          options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, files, _, error in

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
    func unifiedSearchFiles(userBaseUrl: NCUserBaseUrl, literal: String, providers: @escaping (_ accout: String, _ searchProviders: [NKSearchProvider]?) -> Void, update: @escaping (_ account: String, _ id: String, NKSearchResult?, [tableMetadata]?) -> Void, completion: @escaping (_ account: String, _ error: NKError) -> Void) {

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        dispatchGroup.notify(queue: .main) {
            completion(userBaseUrl.account, NKError())
        }

        NextcloudKit.shared.unifiedSearch(term: literal, timeout: 30, timeoutProvider: 90) { _ in
            // example filter
            // ["calendar", "files", "fulltextsearch"].contains(provider.id)
            return true
        } request: { request in
            if let request = request {
                self.requestsUnifiedSearch.append(request)
            }
        } providers: { account, searchProviders in
            providers(account, searchProviders)
        } update: { account, partialResult, provider, _ in
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
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: filePath, dispatchGroup: dispatchGroup) { _, metadata, _ in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    } else { print(#function, "[ERROR]: File search entry has no path: \(entry)") }
                })
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
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: dir + filename, dispatchGroup: dispatchGroup) { _, metadata, _ in
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
        } completion: { _, _, _ in
            self.requestsUnifiedSearch.removeAll()
            dispatchGroup.leave()
        }
    }

    func unifiedSearchFilesProvider(userBaseUrl: NCUserBaseUrl, id: String, term: String, limit: Int, cursor: Int, completion: @escaping (_ account: String, _ searchResult: NKSearchResult?, _ metadatas: [tableMetadata]?, _ error: NKError) -> Void) {

        var metadatas: [tableMetadata] = []

        let request = NextcloudKit.shared.searchProvider(id, account: userBaseUrl.account, term: term, limit: limit, cursor: cursor, timeout: 60) { account, searchResult, _, error in
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
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: filePath, dispatchGroup: nil) { _, metadata, _ in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    } else { print(#function, "[ERROR]: File search entry has no path: \(entry)") }
                })
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
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: dir + filename, dispatchGroup: nil) { _, metadata, _ in
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

    func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, userId: String, overwrite: Bool = false, withPush: Bool, completion: @escaping (_ error: NKError) -> Void) {

        let isDirectoryEncrypted = utilityFileSystem.isDirectoryE2EE(account: account, urlBase: urlBase, userId: userId, serverUrl: serverUrl)
        let fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)

        if isDirectoryEncrypted {
#if !EXTENSION
            Task {
                let error = await NCNetworkingE2EECreateFolder().createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId, withPush: withPush)
                completion(error)
            }
#endif
        } else {
            createFolderPlain(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, overwrite: overwrite, withPush: withPush, completion: completion)
        }
    }

    private func createFolderPlain(fileName: String, serverUrl: String, account: String, urlBase: String, overwrite: Bool, withPush: Bool, completion: @escaping (_ error: NKError) -> Void) {

        var fileNameFolder = utility.removeForbiddenCharacters(fileName)
        if fileName != fileNameFolder {
            let errorDescription = String(format: NSLocalizedString("_forbidden_characters_", comment: ""), NCGlobal.shared.forbiddenCharacters.joined(separator: " "))
            let error = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: errorDescription)
            return completion(error)
        }

        if !overwrite {
            fileNameFolder = utilityFileSystem.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        }
        if fileNameFolder.isEmpty {
            return completion(NKError())
        }
        let fileNameFolderUrl = serverUrl + "/" + fileNameFolder

        NextcloudKit.shared.createFolder(serverUrlFileName: fileNameFolderUrl) { account, _, _, error in
            guard error == .success else {
                if error.errorCode == NCGlobal.shared.errorMethodNotSupported && overwrite {
                    completion(NKError())
                } else {
                    completion(error)
                }
                return
            }

            self.readFile(serverUrlFileName: fileNameFolderUrl) { account, metadataFolder, error in

                if error == .success {
                    if let metadata = metadataFolder {
                        NCManageDatabase.shared.addMetadata(metadata)
                        NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: fileNameFolderUrl, account: account)
                    }
                    if let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadataFolder?.ocId) {
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "withPush": withPush])
                    }
                }
                completion(error)
            }
        }
    }

    func createFolder(assets: [PHAsset], selector: String, useSubFolder: Bool, account: String, urlBase: String, userId: String, withPush: Bool) -> Bool {

        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: urlBase, userId: userId, account: account)
        let serverUrlBase = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: urlBase, userId: userId, account: account)
        let fileNameBase = NCManageDatabase.shared.getAccountAutoUploadFileName()
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
                if autoUploadSubfolderGranularity == NCGlobal.shared.subfolderGranularityYearly {
                    datesSubFolder.append("\(year)")
                } else if autoUploadSubfolderGranularity == NCGlobal.shared.subfolderGranularityDaily {
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
                if result && autoUploadSubfolderGranularity >= NCGlobal.shared.subfolderGranularityMonthly {
                    let month = subfolderArray[1]
                    let serverUrlMonth = autoUploadPath + "/" + year
                    result = createFolder(fileName: String(month), serverUrl: serverUrlMonth)
                    if result && autoUploadSubfolderGranularity == NCGlobal.shared.subfolderGranularityDaily {
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

    func deleteMetadata(_ metadata: tableMetadata, onlyLocalCache: Bool) async -> (NKError) {

        if onlyLocalCache {

            var metadatas = [metadata]

            if metadata.directory {
                let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == false", metadata.account, serverUrl))
            }

            for metadata in metadatas {

                let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
                NCManageDatabase.shared.deleteVideo(metadata: metadata)
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))

                if let metadataLive {
                    NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadataLive.ocId))
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
                }
            }
            return NKError()
        }

        if metadata.isDirectoryE2EE {
#if !EXTENSION
            if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                let error = await NCNetworkingE2EEDelete().delete(metadata: metadataLive)
                if error == .success {
                    return await NCNetworkingE2EEDelete().delete(metadata: metadata)
                } else {
                    return error
                }
            } else {
                return await NCNetworkingE2EEDelete().delete(metadata: metadata)
            }
#else
            return NKError()
#endif
        } else {
            if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                let error = await deleteMetadataPlain(metadataLive)
                if error == .success {
                    return await deleteMetadataPlain(metadata)
                } else {
                    return error
                }
            } else {
                return await deleteMetadataPlain(metadata)
            }
        }
    }

    func deleteMetadataPlain(_ metadata: tableMetadata, customHeader: [String: String]? = nil) async -> NKError {

        // verify permission
        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanDelete)
        if !metadata.permissions.isEmpty && permission == false {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_delete_file_")
        }

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let options = NKRequestOptions(customHeader: customHeader)

        let result = await NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, options: options)

        if result.error == .success || result.error.errorCode == NCGlobal.shared.errorResourceNotFound {

            do {
                try FileManager.default.removeItem(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            } catch { }

            NCManageDatabase.shared.deleteVideo(metadata: metadata)
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

            if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                do {
                    try FileManager.default.removeItem(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
                } catch { }

                NCManageDatabase.shared.deleteVideo(metadata: metadataLive)
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadataLive.ocId))
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadataLive.ocId))
            }

            if metadata.directory {
                NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
            }
        }

        return result.error
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

        let fileName = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)
        let favorite = !metadata.favorite
        let ocId = metadata.ocId

        NextcloudKit.shared.setFavorite(fileName: fileName, favorite: favorite) { account, error in
            if error == .success && metadata.account == account {
                NCManageDatabase.shared.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite)
                if favorite, metadata.directory {
                    let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                    self.synchronizationServerUrl(serverUrl, account: metadata.account, selector: NCGlobal.shared.selectorSynchronizationFavorite)
                }
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterFavoriteFile, userInfo: ["ocId": ocId, "serverUrl": metadata.serverUrl])
            }
            completion(error)
        }
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

    // MARK: - WebDav Rename

    func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, indexPath: IndexPath, viewController: UIViewController?, completion: @escaping (_ error: NKError) -> Void) {

        let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        let fileNameNew = fileNameNew.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileNameNewLive = (fileNameNew as NSString).deletingPathExtension + ".mov"

        if metadata.isDirectoryE2EE {
#if !EXTENSION
            Task {
                if let metadataLive = metadataLive {
                    let error = await NCNetworkingE2EERename().rename(metadata: metadataLive, fileNameNew: fileNameNew, indexPath: indexPath)
                    if error == .success {
                        let error = await NCNetworkingE2EERename().rename(metadata: metadata, fileNameNew: fileNameNew, indexPath: indexPath)
                        DispatchQueue.main.async { completion(error) }
                    } else {
                        DispatchQueue.main.async { completion(error) }
                    }
                } else {
                    let error = await NCNetworkingE2EERename().rename(metadata: metadata, fileNameNew: fileNameNew, indexPath: indexPath)
                    DispatchQueue.main.async { completion(error) }
                }
            }
#endif
        } else {
            if metadataLive == nil {
                renameMetadataPlain(metadata, fileNameNew: fileNameNew, indexPath: indexPath, completion: completion)
            } else {
                renameMetadataPlain(metadataLive!, fileNameNew: fileNameNewLive, indexPath: indexPath) { error in
                    if error == .success {
                        self.renameMetadataPlain(metadata, fileNameNew: fileNameNew, indexPath: indexPath, completion: completion)
                    } else {
                        completion(error)
                    }
                }
            }
        }
    }

    private func renameMetadataPlain(_ metadata: tableMetadata, fileNameNew: String, indexPath: IndexPath, completion: @escaping (_ error: NKError) -> Void) {

        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !metadata.permissions.isEmpty && !permission {
            return completion(NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }
        let fileName = utility.removeForbiddenCharacters(fileNameNew)
        if fileName != fileNameNew {
            let errorDescription = String(format: NSLocalizedString("_forbidden_characters_", comment: ""), NCGlobal.shared.forbiddenCharacters.joined(separator: " "))
            let error = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: errorDescription)
            return completion(error)
        }
        let fileNameNew = fileName
        if fileNameNew.isEmpty || fileNameNew == metadata.fileNameView {
            return completion(NKError())
        }

        let fileNamePath = metadata.serverUrl + "/" + metadata.fileName
        let fileNameToPath = metadata.serverUrl + "/" + fileNameNew
        let ocId = metadata.ocId

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false) { _, error in

            if error == .success {

                NCManageDatabase.shared.renameMetadata(fileNameTo: fileNameNew, ocId: ocId)

                if metadata.directory {

                    let serverUrl = self.utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)
                    let serverUrlTo = self.utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: fileNameNew)
                    if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {

                        NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: serverUrlTo, etag: "", ocId: nil, fileId: nil, encrypted: directory.e2eEncrypted, richWorkspace: nil, account: metadata.account)
                    }

                } else {

                    let ext = (metadata.fileName as NSString).pathExtension
                    let extNew = (fileNameNew as NSString).pathExtension

                    if ext != extNew {

                        self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId))
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced)

                    } else {

                        NCManageDatabase.shared.setLocalFile(ocId: ocId, fileName: fileNameNew, etag: nil)
                        // Move file system
                        let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId) + "/" + metadata.fileName
                        let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId) + "/" + fileNameNew
                        do {
                            try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                        } catch { }
                    }
                }

                if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRenameFile, userInfo: ["ocId": metadata.ocId, "account": metadata.account, "indexPath": indexPath])
                }
            }

            completion(error)
        }
    }

    // MARK: - WebDav Move

    func moveMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) async -> NKError {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            let error = await moveMetadataPlain(metadataLive, serverUrlTo: serverUrlTo, overwrite: overwrite)
            if error == .success {
                return await moveMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite)
            } else {
                return error
            }
        }
        return await moveMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite)
    }

    private func moveMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) async -> NKError {

        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !metadata.permissions.isEmpty && !permission {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_")
        }

        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        let result = await NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite)
        if result.error == .success {
            if metadata.directory {
                NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: result.account)
            }
            NCManageDatabase.shared.moveMetadata(ocId: metadata.ocId, serverUrlTo: serverUrlTo)
        }

        return result.error
    }

    // MARK: - WebDav Copy

    func copyMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) async -> NKError {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            let error = await copyMetadataPlain(metadataLive, serverUrlTo: serverUrlTo, overwrite: overwrite)
            if error == .success {
                return await copyMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite)
            } else {
                return error
            }
        }
        return await copyMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite)
    }

    private func copyMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) async -> NKError {

        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !metadata.permissions.isEmpty && !permission {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_")
        }

        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        let result = await NextcloudKit.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite)
        return result.error
    }

    // MARK: - Direct Download

    func getVideoUrl(metadata: tableMetadata, completition: @escaping (_ url: URL?, _ autoplay: Bool, _ error: NKError) -> Void) {

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

class NCOperationDownload: ConcurrentOperation {

    var metadata: tableMetadata
    var selector: String

    init(metadata: tableMetadata, selector: String) {
        self.metadata = tableMetadata.init(value: metadata)
        self.selector = selector
    }

    override func start() {

        guard !isCancelled else { return self.finish() }

        NCNetworking.shared.download(metadata: metadata, selector: self.selector) { _, _ in
            self.finish()
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
