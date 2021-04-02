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

import Foundation
import OpenSSL
import NCCommunication
import Alamofire
import Queuer

@objc public protocol NCNetworkingDelegate {
    @objc optional func downloadProgress(_ progress: Double, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadProgress(_ progress: Double, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Int64, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String)
}

@objc class NCNetworking: NSObject, NCCommunicationCommonDelegate {
    @objc public static let shared: NCNetworking = {
        let instance = NCNetworking()
        return instance
    }()
        
    var delegate: NCNetworkingDelegate?
    
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
    
    //MARK: - init
    
    override init() {
        super.init()
        
        #if EXTENSION
        _ = sessionIdentifierBackgroundExtension
        #else
        _ = sessionManagerBackground
        _ = sessionManagerBackgroundWWan
        #endif
    }
    
    //MARK: - Communication Delegate
       
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
    
    func authenticationChallenge(_ challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if checkTrustedChallenge(challenge: challenge, directoryCertificate: CCUtility.getDirectoryCerificates()) {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential.init(trust: challenge.protectionSpace.serverTrust!))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }
    
    func downloadProgress(_ progress: Double, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
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
    
    //MARK: - Pinning check
    
    @objc func checkTrustedChallenge(challenge: URLAuthenticationChallenge, directoryCertificate: String) -> Bool {
        
        var trusted = false
        let protectionSpace: URLProtectionSpace = challenge.protectionSpace
        let directoryCertificateUrl = URL.init(fileURLWithPath: directoryCertificate)
        
        if let trust: SecTrust = protectionSpace.serverTrust {
            saveX509Certificate(trust, certName: "tmp.der", directoryCertificate: directoryCertificate)
            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryCertificateUrl, includingPropertiesForKeys: nil)
                let certTmpPath = directoryCertificate+"/"+"tmp.der"
                for file in directoryContents {
                    let certPath = file.path
                    if certPath == certTmpPath { continue }
                    if FileManager.default.contentsEqual(atPath:certTmpPath, andPath: certPath) {
                        trusted = true
                        break
                    }
                }
            } catch { print(error) }
        }
        
        return trusted
    }
    
    @objc func writeCertificate(directoryCertificate: String) {
        
        let stringDate: String = String(Date().timeIntervalSince1970)
        let certificateAtPath = directoryCertificate + "/tmp.der"
        let certificateToPath = directoryCertificate + "/" + stringDate + ".der"
        
        do {
            try FileManager.default.moveItem(atPath: certificateAtPath, toPath: certificateToPath)
        } catch { }
    }
    
    private func saveX509Certificate(_ trust: SecTrust, certName: String, directoryCertificate: String) {
        
        let currentServerCert = secTrustGetLeafCertificate(trust)
        let certNamePath = directoryCertificate + "/" + certName
        let data: CFData = SecCertificateCopyData(currentServerCert!)
        let mem = BIO_new_mem_buf(CFDataGetBytePtr(data), Int32(CFDataGetLength(data)))
        let x509cert = d2i_X509_bio(mem, nil)

        BIO_free(mem)
        if x509cert == nil {
            print("[LOG] OpenSSL couldn't parse X509 Certificate")
        } else {
            if FileManager.default.fileExists(atPath: certNamePath) {
                do {
                    try FileManager.default.removeItem(atPath: certNamePath)
                } catch { }
            }
            let file = fopen(certNamePath, "w")
            if file != nil {
                PEM_write_X509(file, x509cert);
            }
            fclose(file);
            X509_free(x509cert);
        }
    }
    
    private func secTrustGetLeafCertificate(_ trust: SecTrust) -> SecCertificate? {
        
        let result: SecCertificate?
        
        if SecTrustGetCertificateCount(trust) > 0 {
            result = SecTrustGetCertificateAtIndex(trust, 0)!
            assert(result != nil);
        } else {
            result = nil
        }
        
        return result
    }
        
    //MARK: - Utility
    
    func cancelTaskWithUrl(_ url: URL) {
        NCCommunication.shared.getSessionManager().getAllTasks  { tasks in
            tasks.filter { $0.state == .running }.filter { $0.originalRequest?.url == url }.first?.cancel()
        }
    }
    
    @objc func cancelAllTask() {
        NCCommunication.shared.getSessionManager().getAllTasks  { tasks in
            for task in tasks {
                task.cancel()
            }
        }
    }
    
    //MARK: - Download
    
    @objc func cancelDownload(ocId: String, serverUrl:String, fileNameView: String) {
        
        guard let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView) else { return }
        
        if let request = downloadRequest[fileNameLocalPath] {
            request.cancel()
        } else {
            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                NCManageDatabase.shared.setMetadataSession(ocId: ocId, session: "", sessionError: "", sessionSelector: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile, userInfo: ["ocId":metadata.ocId])
                
            }
        }
    }
    
    @objc func download(metadata: tableMetadata, activityIndicator: Bool, selector: String, completion: @escaping (_ errorCode: Int)->()) {
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
        
        if NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) == nil {
            NCManageDatabase.shared.addMetadata(tableMetadata.init(value: metadata))
        }
            
        if metadata.status == NCGlobal.shared.metadataStatusInDownload || metadata.status == NCGlobal.shared.metadataStatusDownloading { return }
                
        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: NCCommunicationCommon.shared.sessionIdentifierDownload, sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusInDownload)
                    
        if activityIndicator {
            NCUtility.shared.startActivityIndicator(backgroundView: nil, blurEffect: true)
        }
        
        NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { (request) in
            
            self.downloadRequest[fileNameLocalPath] = request
            
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusDownloading)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadStartFile, userInfo: ["ocId":metadata.ocId])
            
        }, taskHandler: { (_) in
            
        }, progressHandler: { (progress) in
            
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterProgressTask, object: nil, userInfo: ["account":metadata.account, "ocId":metadata.ocId, "serverUrl":metadata.serverUrl, "status":NSNumber(value: NCGlobal.shared.metadataStatusInDownload), "progress":NSNumber(value: progress.fractionCompleted), "totalBytes":NSNumber(value: progress.totalUnitCount), "totalBytesExpected":NSNumber(value: progress.completedUnitCount)])
            
        }) { (account, etag, date, length, allHeaderFields, error, errorCode, errorDescription) in
              
            if activityIndicator {
                NCUtility.shared.stopActivityIndicator()
            }
            
            if error?.isExplicitlyCancelledError ?? false {
                            
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal)
            
            } else if errorCode == 0 {
               
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusNormal, etag: etag)
                NCManageDatabase.shared.addLocalFile(metadata: metadata)
                
                #if !EXTENSION
                if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@", metadata.fileName, metadata.serverUrl)) {
                    
                    NCEndToEndEncryption.sharedManager()?.decryptFileName(metadata.fileName, fileNameView: metadata.fileNameView, ocId: metadata.ocId, key: result.key, initializationVector: result.initializationVector, authenticationTag: result.authenticationTag)
                }
                CCUtility.setExif(metadata) { (latitude, longitude, location, date, lensMode) in };
                #endif
                                
            } else {
                                
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: errorDescription, sessionSelector: selector, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusDownloadError)
                
                #if !EXTENSION
                if errorCode == 401 || errorCode == 403 {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: metadata.account)
                } else if errorCode == Int(CFNetworkErrors.cfurlErrorServerCertificateUntrusted.rawValue) {
                    CCUtility.setCertificateError(metadata.account, error: true)
                }
                #endif
            }
            
            self.downloadRequest[fileNameLocalPath] = nil
            if error?.isExplicitlyCancelledError ?? false {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile, userInfo: ["ocId":metadata.ocId])
            } else {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId":metadata.ocId, "selector":selector, "errorCode":errorCode, "errorDescription":errorDescription])
            }
            
            completion(errorCode)
        }
    }
    
    //MARK: - Upload

    @objc func upload(metadata: tableMetadata, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->())  {
           
        let metadata = tableMetadata.init(value: metadata)

        guard let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", metadata.account)) else {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            completion(NCGlobal.shared.ErrorInternalError, "Internal error")
            return
        }
        
        var fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                   
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            let metadata = tableMetadata.init(value: metadata)
            
            let results = NCCommunicationCommon.shared.getInternalType(fileName: metadata.fileNameView, mimeType: metadata.contentType, directory: false)
            metadata.contentType = results.mimeType
            metadata.iconName = results.iconName
            metadata.typeFile = results.typeFile
            if let date = NCUtilityFileSystem.shared.getFileCreationDate(filePath: fileNameLocalPath) {
                 metadata.creationDate = date
            }
            if let date =  NCUtilityFileSystem.shared.getFileModificationDate(filePath: fileNameLocalPath) {
                metadata.date = date
            }
            metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: fileNameLocalPath)
               
            NCManageDatabase.shared.addMetadata(metadata)
           
            if metadata.e2eEncrypted {
                #if !EXTENSION
                NCNetworkingE2EE.shared.upload(metadata: tableMetadata.init(value: metadata), account: account, completion: completion)
                #endif
            } else if metadata.chunk {
                uploadChunkFile(metadata: tableMetadata.init(value: metadata), account: account, completion: completion)
            } else if metadata.session == NCCommunicationCommon.shared.sessionIdentifierUpload {
                uploadFile(metadata: tableMetadata.init(value: metadata), account: account, completion: completion)
            } else {
                uploadFileInBackground(metadata: tableMetadata.init(value: metadata), account: account, completion: completion)
            }
           
        } else {
               
            CCUtility.extractImageVideoFromAssetLocalIdentifier(forUpload: metadata, notification: true) { (extractMetadata, fileNamePath) in
                   
                guard let extractMetadata = extractMetadata else {
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    completion(NCGlobal.shared.ErrorInternalError, "Internal error")
                    return
                }
                       
                fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(extractMetadata.ocId, fileNameView: extractMetadata.fileNameView)
                NCUtilityFileSystem.shared.moveFileInBackground(atPath: fileNamePath!, toPath: fileNameLocalPath)

                NCManageDatabase.shared.addMetadata(extractMetadata)
               
                if metadata.e2eEncrypted {
                    #if !EXTENSION
                    NCNetworkingE2EE.shared.upload(metadata: tableMetadata.init(value: extractMetadata), account: account, completion: completion)
                    #endif
                } else if metadata.chunk {
                    self.uploadChunkFile(metadata: tableMetadata.init(value: extractMetadata), account: account, completion: completion)
                } else if metadata.session == NCCommunicationCommon.shared.sessionIdentifierUpload {
                    self.uploadFile(metadata: tableMetadata.init(value: extractMetadata), account: account, completion: completion)
                } else {
                    self.uploadFileInBackground(metadata: tableMetadata.init(value: extractMetadata), account: account, completion: completion)
                }
            }
        }
    }
    
    private func uploadFile(metadata: tableMetadata, account: tableAccount, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        var uploadTask: URLSessionTask?
        let description = metadata.ocId
        
        NCCommunication.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, customUserAgent: nil, addCustomHeaders: nil, requestHandler: { (request) in
            
            self.uploadRequest[fileNameLocalPath] = request
        
        }, taskHandler: { (task) in
            
            uploadTask = task
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId":metadata.ocId])
            
        }, progressHandler: { (progress) in
            
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterProgressTask, userInfo: ["account":metadata.account, "ocId":metadata.ocId, "serverUrl":metadata.serverUrl, "status":NSNumber(value: NCGlobal.shared.metadataStatusInUpload), "progress":NSNumber(value: progress.fractionCompleted), "totalBytes":NSNumber(value: progress.totalUnitCount), "totalBytesExpected":NSNumber(value: progress.completedUnitCount)])
            
        }) { (account, ocId, etag, date, size, allHeaderFields, error, errorCode, errorDescription) in
         
            self.uploadRequest[fileNameLocalPath] = nil
            self.uploadComplete(fileName: metadata.fileName, serverUrl: metadata.serverUrl, ocId: ocId, etag: etag, date: date, size: size, description: description, task: uploadTask!, errorCode: errorCode, errorDescription: errorDescription)
            
            completion(errorCode, errorDescription)
        }
    }
    
    private func uploadChunkFile(metadata: tableMetadata, account: tableAccount, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let folder = NSUUID().uuidString
        let uploadFolder = metadata.urlBase + "/" + NCUtilityFileSystem.shared.getDAV() + "/uploads/" + account.userId + "/" + folder
        var uploadErrorCode: Int = 0
        var uploadErrorDescription = ""
        
        NCCommunication.shared.createFolder(uploadFolder) { (account, ocId, date, errorCode, errorDescription) in
            
            if errorCode == 0 {
                
                let path = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId)!
                if let filesNames = self.fileChunks(path: path, fileName: metadata.fileName, pathChunks: path, size: 10) {
                    
                    DispatchQueue.global(qos: .background).async {
                        
                        for fileName in filesNames {
                                                    
                            let serverUrlFileName = uploadFolder + "/" + fileName
                            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: fileName)!
                            let semaphore = Semaphore()

                            NCCommunication.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, customUserAgent: nil, addCustomHeaders: nil, requestHandler: { (request) in
                                //
                            }, taskHandler: { (task) in
                                //
                            }, progressHandler: { (progress) in
                                //
                            }) { (account, ocId, etag, date, size, allHeaderFields, error, errorCode, errorDescription) in
                                
                                uploadErrorCode = errorCode
                                uploadErrorDescription = errorDescription
                                semaphore.continue()
                            }
                            
                            semaphore.wait()
                            
                            if uploadErrorCode != 0 {
                                print("error upload")
                                break
                            }
                        }
                        
                        
                        if uploadErrorCode == 0 {
                            
                            // Assembling the chunks
                            
                            //curl -X MOVE -u roeland:pass --header 'X-OC-Mtime:1547545326' --header 'Destination:https://server/remote.php/dav/files/roeland/dest/file.zip' https://server/remote.php/dav/uploads/roeland/myapp-e1663913-4423-4efe-a9cd-26e7beeca3c0/.file”
                            
                        } else {
                            
                            // Aborting the upload
                            
                            //curl -X DELETE -u roeland:pass https://server/remote.php/dav/uploads/roeland/myapp-e1663913-4423-4efe-a9cd-26e7beeca3c0/
                        }
                    }
                } else {
                    print("error chunk filename")
                }
                
            } else {
                print("error create directory")
            }
        }
    }
    
    private func uploadFileInBackground(metadata: tableMetadata, account: tableAccount, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        var session: URLSession?
        let metadata = tableMetadata.init(value: metadata)
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        
        if metadata.session == sessionIdentifierBackground || metadata.session == sessionIdentifierBackgroundExtension {
            session = sessionManagerBackground
        } else if metadata.session == sessionIdentifierBackgroundWWan {
            session = sessionManagerBackgroundWWan
        }
        
        // Check file dim > 0
        if NCUtilityFileSystem.shared.getFileSize(filePath: fileNameLocalPath) == 0 {
        
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            completion(404, NSLocalizedString("_error_not_found_", value: "The requested resource could not be found", comment: ""))
        
        } else {
        
            if let task = NCCommunicationBackground.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, description: metadata.ocId, session: session!) {
                         
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading)
                
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId":metadata.ocId])
                
                completion(0, "")
                
            } else {
                
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                completion(NCGlobal.shared.ErrorInternalError, "task null")
            }
        }
    }
    
    func uploadProgress(_ progress: Double, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.uploadProgress?(progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected, fileName: fileName, serverUrl: serverUrl, session: session, task: task)
        
        var metadata: tableMetadata?
        let description: String = task.taskDescription ?? ""
        
        if let metadataTmp = self.uploadMetadataInBackground[fileName+serverUrl] {
            metadata = metadataTmp
        } else if let metadataTmp = NCManageDatabase.shared.getMetadataFromOcId(description){
            self.uploadMetadataInBackground[fileName+serverUrl] = metadataTmp
            metadata = metadataTmp
        }
        
        if metadata != nil {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterProgressTask, userInfo: ["account":metadata!.account, "ocId":metadata!.ocId, "serverUrl":serverUrl, "status":NSNumber(value: NCGlobal.shared.metadataStatusInUpload), "progress":NSNumber(value: progress), "totalBytes":NSNumber(value: totalBytes), "totalBytesExpected":NSNumber(value: totalBytesExpected)])
        }
    }
    
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String) {
        if delegate != nil {
            delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size:size, description: description, task: task, errorCode: errorCode, errorDescription: errorDescription)
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
                    metadata.deleteAssetLocalIdentifier = true;
                }
                
                if CCUtility.getDisableLocalCacheAfterUpload() {
                    CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } else {
                    NCManageDatabase.shared.addLocalFile(metadata: metadata)
                }
                NCManageDatabase.shared.addMetadata(metadata)
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
                
                #if !EXTENSION
                self.getOcIdInBackgroundSession { (listOcId) in
                    if listOcId.count == 0 && self.uploadRequest.count == 0 {
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        appDelegate.networkingProcessUpload?.startProcess()
                    }
                }
                CCUtility.setExif(metadata) { (latitude, longitude, location, date, lensMode) in };
                #endif                
                
                NCCommunicationCommon.shared.writeLog("Upload complete " + serverUrl + "/" + fileName + ", result: success(\(size) bytes)")
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId":metadata.ocId, "ocIdTemp":ocIdTemp, "errorCode":errorCode, "errorDescription":""])
                
            } else {
                
                if errorCode == NSURLErrorCancelled || errorCode == NCGlobal.shared.ErrorRequestExplicityCancelled {
                
                    if metadata.status == NCGlobal.shared.metadataStatusUploadForcedStart {
                        
                        NCManageDatabase.shared.setMetadataSession(ocId: ocId!, session: sessionIdentifierBackground, sessionError: "", sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusInUpload)
                        NCNetworking.shared.upload(metadata: metadata) { (_, _) in }
                                                
                    } else {
                        
                        CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                        NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    }
                    
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId":metadata.ocId, "serverUrl":metadata.serverUrl, "account":metadata.account])
                
                } else if errorCode == 401 || errorCode == 403 {
                    
                    #if !EXTENSION
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: metadata.account)
                    #endif
                    
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)

                } else if errorCode == Int(CFNetworkErrors.cfurlErrorServerCertificateUntrusted.rawValue) {
                    
                    CCUtility.setCertificateError(metadata.account, error: true)
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)

                } else {
                    
                    if size == 0 {
                        errorDescription = "File length 0"
                        NCCommunicationCommon.shared.writeLog("Upload error 0 length " + serverUrl + "/" + fileName + ", result: success(\(size) bytes)")
                    }
                    
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)
                }
                
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId":metadata.ocId, "ocIdTemp":ocIdTemp, "errorCode":errorCode, "errorDescription":""])
            }
            
            // Delete
            self.uploadMetadataInBackground[fileName+serverUrl] = nil
        }
    }
    
    @objc func verifyUploadZombie() {
        
        var session: URLSession?
        
        // verify metadataStatusInUpload (BACKGROUND)
        let metadatasInUploadBackground = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d AND sessionTaskIdentifier == 0", sessionIdentifierBackground, sessionIdentifierBackgroundExtension, sessionIdentifierBackgroundWWan, NCGlobal.shared.metadataStatusInUpload))
        for metadata in metadatasInUploadBackground {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d AND sessionTaskIdentifier == 0", metadata.ocId, NCGlobal.shared.metadataStatusInUpload)) {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: self.sessionIdentifierBackground, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusWaitUpload)
                }
            }
        }
        
        // metadataStatusUploading (BACKGROUND)
        let metadatasUploadingBackground = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d", sessionIdentifierBackground, sessionIdentifierBackgroundWWan, sessionIdentifierBackgroundExtension, NCGlobal.shared.metadataStatusUploading))
        for metadata in metadatasUploadingBackground {
            
            if metadata.session == sessionIdentifierBackground {
                session = self.sessionManagerBackground
            } else if metadata.session == sessionIdentifierBackgroundWWan {
                session = self.sessionManagerBackgroundWWan
            }
            
            var taskUpload: URLSessionTask?
            
            session?.getAllTasks(completionHandler: { (tasks) in
                for task in tasks {
                    if task.taskIdentifier == metadata.sessionTaskIdentifier {
                        taskUpload = task
                    }
                }
                
                if taskUpload == nil {
                    if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d", metadata.ocId, NCGlobal.shared.metadataStatusUploading)) {
                        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: self.sessionIdentifierBackground, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusWaitUpload)
                    }
                }
            })
        }
        
        // metadataStatusUploading
        let metadatasUploading = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", NCCommunicationCommon.shared.sessionIdentifierUpload, NCGlobal.shared.metadataStatusUploading))
        for metadata in metadatasUploading {
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            if uploadRequest[fileNameLocalPath] == nil {
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusWaitUpload)
            }
        }
    }
    
    func getOcIdInBackgroundSession(completion: @escaping (_ listOcId: [String])->()) {
        
        var listOcId: [String] = []
        
        sessionManagerBackground.getAllTasks(completionHandler: { (tasks) in
            for task in tasks {
                listOcId.append(task.description)
            }
            self.sessionManagerBackgroundWWan.getAllTasks(completionHandler: { (tasks) in
                for task in tasks {
                    listOcId.append(task.description)
                }
                completion(listOcId)
            })
        })
    }
    
    //MARK: - Transfer (Download Upload)
    
    @objc func cancelTransferMetadata(_ metadata: tableMetadata, completion: @escaping ()->()) {
        
        let metadata = tableMetadata.init(value: metadata)

        if metadata.session.count == 0 {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            completion()
            return
        }

        if metadata.session == NCCommunicationCommon.shared.sessionIdentifierDownload {
            
            NCNetworking.shared.cancelDownload(ocId: metadata.ocId, serverUrl: metadata.serverUrl, fileNameView: metadata.fileNameView)
            completion()
            return
        }
        
        if metadata.session == NCCommunicationCommon.shared.sessionIdentifierUpload {
            
            guard let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView) else { return }
            
            if let request = uploadRequest[fileNameLocalPath] {
                request.cancel()
            } else {
                CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId":metadata.ocId, "serverUrl":metadata.serverUrl, "account":metadata.account])
            }
            
            completion()
            return
        }
        
        var session: URLSession?
        if metadata.session == NCNetworking.shared.sessionIdentifierBackground {
            session = NCNetworking.shared.sessionManagerBackground
        } else if metadata.session == NCNetworking.shared.sessionIdentifierBackgroundWWan {
            session = NCNetworking.shared.sessionManagerBackgroundWWan
        }
        if session == nil {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId":metadata.ocId, "serverUrl":metadata.serverUrl, "account":metadata.account])
            completion()
            return
        }
        
        session?.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) in
            
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
                    }
                    catch { }
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId":metadata.ocId, "serverUrl":metadata.serverUrl, "account":metadata.account])
                }
            }
            completion()
        }
    }
    
    @objc func cancelAllTransfer(account: String, completion: @escaping ()->()) {
       
        NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "status == %d OR status == %d", account, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploadError))
        
        let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status != %d", NCGlobal.shared.metadataStatusNormal))
        
        var counter = 0
        for metadata in metadatas {
            counter += 1

            if (metadata.status == NCGlobal.shared.metadataStatusWaitDownload || metadata.status == NCGlobal.shared.metadataStatusDownloadError) {
                
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
        
    //MARK: - WebDav Read file, folder
    
    @objc func readFolder(serverUrl: String, account: String, completion: @escaping (_ account: String, _ metadataFolder: tableMetadata?, _ metadatas: [tableMetadata]?, _ metadatasUpdate: [tableMetadata]?, _ metadatasLocalUpdate: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String)->()) {
        
        NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: CCUtility.getShowHiddenFiles()) { (account, files, responseData, errorCode, errorDescription) in
            
            if errorCode == 0  {
                              
                NCManageDatabase.shared.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: true, account: account) { (metadataFolder, metadatasFolder, metadatas) in
                    
                    // Add metadata folder
                    NCManageDatabase.shared.addMetadata(tableMetadata.init(value: metadataFolder))
                    
                    // Update directory
                    NCManageDatabase.shared.addDirectory(encrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, serverUrl: serverUrl, richWorkspace: metadataFolder.richWorkspace, account: metadataFolder.account)
                    
                    // Update sub directories
                    for metadata in metadatasFolder {
                        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                        NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, richWorkspace: metadata.richWorkspace, account: account)
                    }
                    
                    let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, NCGlobal.shared.metadataStatusNormal))
                    let metadatasChanged = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareEtagLocal: true)
                    
                    completion(account, metadataFolder, metadatas, metadatasChanged.metadatasUpdate, metadatasChanged.metadatasLocalUpdate, errorCode, "")
                }
            
            } else {
                
                completion(account, nil, nil, nil, nil, errorCode, errorDescription)
            }
        }
    }
    
    @objc func readFile(serverUrlFileName: String, account: String, completion: @escaping (_ account: String, _ metadata: tableMetadata?, _ errorCode: Int, _ errorDescription: String)->()) {
        
        NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles()) { (account, files, responseData, errorCode, errorDescription) in

            if errorCode == 0 && files.count == 1 {
                
                let file = files[0]
                let isEncrypted = CCUtility.isFolderEncrypted(file.serverUrl, e2eEncrypted:file.e2eEncrypted, account: account, urlBase: file.urlBase)
                let metadata = NCManageDatabase.shared.convertNCFileToMetadata(file, isEncrypted: isEncrypted, account: account)
                
                completion(account, metadata, errorCode, errorDescription)
               
            } else {
                
                completion(account, nil, errorCode, errorDescription)
            }
        }
    }
    
    //MARK: - WebDav Search
    
    @objc func searchFiles(urlBase: String, user: String, literal: String, completion: @escaping (_ account: String, _ metadatas: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String)->()) {
        
        NCCommunication.shared.searchLiteral(serverUrl: urlBase, depth: "infinity", literal: literal, showHiddenFiles: CCUtility.getShowHiddenFiles()) { (account, files, errorCode, errorDescription) in
            
            if errorCode == 0  {
                
                NCManageDatabase.shared.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: false, account: account) { (metadataFolder, metadatasFolder, metadatas) in
                    
                    // Update sub directories
                    for metadata in metadatasFolder {
                        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                        NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, richWorkspace: metadata.richWorkspace, account: account)
                    }
                    
                    NCManageDatabase.shared.addMetadatas(metadatas)
                    
                    let metadatas = Array(metadatas.map { tableMetadata.init(value:$0) })
                    
                    completion(account, metadatas, errorCode, errorDescription)
                }
                
            } else {
                              
                completion(account, nil, errorCode, errorDescription)
            }
        }
    }
    
    //MARK: - WebDav Create Folder

    @objc func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, overwrite: Bool = false, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(serverUrl, e2eEncrypted: false, account: account, urlBase: urlBase)
               
        if isDirectoryEncrypted {
            #if !EXTENSION
            NCNetworkingE2EE.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, completion: completion)
            #endif
        } else {
            createFolderPlain(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, overwrite: overwrite, completion: completion)
        }
    }
    
    private func createFolderPlain(fileName: String, serverUrl: String, account: String, urlBase: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        
        if (!overwrite) {
            fileNameFolder = NCUtilityFileSystem.shared.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        }
        if fileNameFolder.count == 0 {
            completion(0, "")
            return
        }
        let fileNameFolderUrl = serverUrl + "/" + fileNameFolder
        
        NCCommunication.shared.createFolder(fileNameFolderUrl) { (account, ocId, date, errorCode, errorDescription) in
            
            if errorCode == 0 {
                
                self.readFile(serverUrlFileName: fileNameFolderUrl, account: account) { (account, metadataFolder, errorCode, errorDescription) in
                    
                    if errorCode == 0 {
                        
                        if let metadata = metadataFolder {
                        
                            NCManageDatabase.shared.addMetadata(metadata)
                            NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: fileNameFolderUrl, richWorkspace: metadata.richWorkspace, account: account)
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
        
        NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, overwrite: true) { (errorCode, errorDescription) in
            if errorCode == 0 { result = true }
            semaphore.continue()
        }
        
        if semaphore.wait() == .success { result = true }
        return result
    }
    
    //MARK: - WebDav Delete

    @objc func deleteMetadata(_ metadata: tableMetadata, account: String, urlBase: String, onlyLocal: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
                
        if (onlyLocal) {
            
            var metadatas = [metadata]
            
            if metadata.directory {
                let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == false", account, serverUrl))
            }
            
            for metadata in metadatas {
            
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCUtilityFileSystem.shared.deleteFile(filePath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
            
                if let metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                    NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadataLivePhoto.ocId))
                    NCUtilityFileSystem.shared.deleteFile(filePath: CCUtility.getDirectoryProviderStorageOcId(metadataLivePhoto.ocId))
                }
            
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": metadata.ocId, "fileNameView": metadata.fileNameView, "typeFile": metadata.typeFile, "onlyLocal": true])
            }
            completion(0, "")
            
            return
        }
        
        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: urlBase)
        let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        
        if isDirectoryEncrypted {
            #if !EXTENSION
            if metadataLive == nil {
                NCNetworkingE2EE.shared.deleteMetadata(metadata, urlBase: urlBase, completion: completion)
            } else {
                NCNetworkingE2EE.shared.deleteMetadata(metadataLive!, urlBase: urlBase) { (errorCode, errorDescription) in
                    if errorCode == 0 {
                        NCNetworkingE2EE.shared.deleteMetadata(metadata, urlBase: urlBase, completion: completion)
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
                self.deleteMetadataPlain(metadataLive!, addCustomHeaders: nil) { (errorCode, errorDescription) in
                    if errorCode == 0 {
                        self.deleteMetadataPlain(metadata, addCustomHeaders: nil, completion: completion)
                    } else {
                        completion(errorCode, errorDescription)
                    }
                }
            }
        }
    }
    
    func deleteMetadataPlain(_ metadata: tableMetadata, addCustomHeaders: [String: String]?, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        // verify permission
        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanDelete)
        if metadata.permissions != "" && permission == false {
            
            completion(NCGlobal.shared.ErrorInternalError, "_no_permission_delete_file_")
            return
        }
                
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCCommunication.shared.deleteFileOrFolder(serverUrlFileName, customUserAgent: nil, addCustomHeaders: addCustomHeaders) { (account, errorCode, errorDescription) in
        
            if errorCode == 0 || errorCode == NCGlobal.shared.ErrorResourceNotFound {
                
                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }
                                       
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

                if metadata.directory {
                    NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
                }
                
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": metadata.ocId, "fileNameView": metadata.fileNameView, "typeFile": metadata.typeFile, "onlyLocal": true])
            }
            
            completion(errorCode, errorDescription)
        }
    }
    
    //MARK: - WebDav Favorite

    @objc func favoriteMetadata(_ metadata: tableMetadata, urlBase: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            favoriteMetadataPlain(metadataLive, urlBase: urlBase) { (errorCode, errorDescription) in
                if errorCode == 0 {
                    self.favoriteMetadataPlain(metadata, urlBase: urlBase, completion: completion)
                } else {
                    completion(errorCode, errorDescription)
                }
            }
        } else {
            favoriteMetadataPlain(metadata, urlBase: urlBase, completion: completion)
        }
    }
    
    private func favoriteMetadataPlain(_ metadata: tableMetadata, urlBase: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: urlBase, account: metadata.account)!
        let favorite = !metadata.favorite
        let ocId = metadata.ocId
        
        NCCommunication.shared.setFavorite(fileName: fileName, favorite: favorite) { (account, errorCode, errorDescription) in
    
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
    
    @objc func listingFavoritescompletion(selector: String, completion: @escaping (_ account: String, _ metadatas: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String)->()) {
        NCCommunication.shared.listingFavorites(showHiddenFiles: CCUtility.getShowHiddenFiles()) { (account, files, errorCode, errorDescription) in
            if errorCode == 0 {
                NCManageDatabase.shared.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: false, account: account) { (_, _, metadatas) in
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
    
    //MARK: - WebDav Rename

    @objc func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, urlBase: String, viewController: UIViewController?, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: urlBase)
        let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        let fileNameNewLive = (fileNameNew as NSString).deletingPathExtension + ".mov"

        if isDirectoryEncrypted {
            #if !EXTENSION
            if metadataLive == nil {
                NCNetworkingE2EE.shared.renameMetadata(metadata, fileNameNew: fileNameNew, urlBase: urlBase, completion: completion)
            } else {
                NCNetworkingE2EE.shared.renameMetadata(metadataLive!, fileNameNew: fileNameNewLive, urlBase: urlBase) { (errorCode, errorDescription) in
                    if errorCode == 0 {
                        NCNetworkingE2EE.shared.renameMetadata(metadata, fileNameNew: fileNameNew, urlBase: urlBase, completion: completion)
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
                renameMetadataPlain(metadataLive!, fileNameNew: fileNameNewLive) { (errorCode, errorDescription) in
                    if errorCode == 0 {
                        self.renameMetadataPlain(metadata, fileNameNew: fileNameNew, completion: completion)
                    } else {
                        completion(errorCode, errorDescription)
                    }
                }
            }
        }
    }
    
    private func renameMetadataPlain(_ metadata: tableMetadata, fileNameNew: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !(metadata.permissions == "") && !permission {
            completion(NCGlobal.shared.ErrorInternalError, "_no_permission_modify_file_")
            return
        }
        guard let fileNameNew = CCUtility.removeForbiddenCharactersServer(fileNameNew) else {
            completion(0, "")
            return
        }
        if fileNameNew.count == 0 || fileNameNew == metadata.fileNameView {
            completion(0, "")
            return
        }
        
        let fileNamePath = metadata.serverUrl + "/" + metadata.fileName
        let fileNameToPath = metadata.serverUrl + "/" + fileNameNew
        let ocId = metadata.ocId
                
        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false) { (account, errorCode, errorDescription) in
                    
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
    
    //MARK: - WebDav Move
    
    @objc func moveMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            moveMetadataPlain(metadataLive, serverUrlTo: serverUrlTo, overwrite: overwrite) { (errorCode, errorDescription) in
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

    private func moveMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
    
        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !(metadata.permissions == "") && !permission {
            completion(NCGlobal.shared.ErrorInternalError, "_no_permission_modify_file_")
            return
        }
        
        let serverUrlFrom = metadata.serverUrl
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
        
        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite) { (account, errorCode, errorDescription) in
                                
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
    
    //MARK: - WebDav Copy
    
    @objc func copyMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            copyMetadataPlain(metadataLive, serverUrlTo: serverUrlTo, overwrite: overwrite) { (errorCode, errorDescription) in
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

    private func copyMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
    
        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !(metadata.permissions == "") && !permission {
            completion(NCGlobal.shared.ErrorInternalError, "_no_permission_modify_file_")
            return
        }
        
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
        
        NCCommunication.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite) { (account, errorCode, errorDescription) in
                   
            if errorCode == 0 {
                
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCopyFile, userInfo: ["ocId": metadata.ocId, "serverUrlTo": serverUrlTo])
            }
            
            completion(errorCode, errorDescription)
        }
    }
    
    //MARK: - TEST API
        
    /*
     
     XXXXXXXXXXXXXXX-YYYYYYYYYYYYYYY

     Where XXXXXXXXXXXXXXX is the start byte of the chunk (with leading zeros) and YYYYYYYYYYYYYYY is the end byte of the chunk with leading zeros.

     curl -X PUT -u roeland:pass https://server/remote.php/dav/uploads/roeland/myapp-e1663913-4423-4efe-a9cd-26e7beeca3c0/000000000000000-000000010485759 -d @chunk1 curl -X PUT -u roeland:pass https://server/remote.php/dav/uploads/roeland/myapp-e1663913-4423-4efe-a9cd-26e7beeca3c0/000000010485760-000000015728640 -d @chunk2

     This will upload 2 chunks of a file. The first chunk is 10MB in size and the second chunk is 5MB in size.
     
     */
    
    func fileChunks(path: String, fileName: String, pathChunks: String, size: Int) -> [String]? {
           
        var filesNameOut: [String] = []
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path + "/" + fileName))
            let dataLen = data.count
            let chunkSize = ((1024 * 1000) * size) // MB
            let fullChunks = Int(dataLen / chunkSize)
            let totalChunks = fullChunks + (dataLen % 1024 != 0 ? 1 : 0)
                
            for chunkCounter in 0..<totalChunks {
                
                let chunkBase = chunkCounter * chunkSize
                var diff = chunkSize
                if chunkCounter == totalChunks - 1 {
                    diff = dataLen - chunkBase
                }
                    
                let range:Range<Data.Index> = chunkBase..<(chunkBase + diff)
                let chunk = data.subdata(in: range)
                                
                let fileNameOut = fileName + "." + String(format: "%010d", chunkCounter)
                try chunk.write(to: URL(fileURLWithPath: pathChunks + "/" + fileNameOut))
                filesNameOut.append(fileNameOut)
            }
        } catch {
            return nil
        }
        
        return filesNameOut
    }
    
    /*
    @objc public func getAppPassword(serverUrl: String, username: String, password: String, customUserAgent: String? = nil, completionHandler: @escaping (_ token: String?, _ errorCode: Int, _ errorDescription: String) -> Void) {
                
        let endpoint = "/ocs/v2.php/core/getapppassword"
        
        let url:URLConvertible = try! (serverUrl + endpoint).asURL() as URLConvertible
        var headers: HTTPHeaders = [.authorization(username: username, password: password)]
        if customUserAgent != nil {
            headers.update(.userAgent(customUserAgent!))
        }
        //headers.update(.contentType("application/json"))
        headers.update(name: "OCS-APIRequest", value: "true")
               
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: HTTPMethod(rawValue: "GET"), headers: headers)
        } catch {
            completionHandler(nil, error._code, error.localizedDescription)
            return
        }
        
        AF.request(urlRequest).validate(statusCode: 200..<300).response { (response) in
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
