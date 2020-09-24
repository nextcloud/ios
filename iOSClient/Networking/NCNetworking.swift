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
    @objc optional func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String)
}

@objc class NCNetworking: NSObject, NCCommunicationCommonDelegate {
    @objc public static let shared: NCNetworking = {
        let instance = NCNetworking()
        return instance
    }()
        
    var delegate: NCNetworkingDelegate?
    
    var lastReachability: Bool = true
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
        configuration.sharedContainerIdentifier = NCBrandOptions.sharedInstance.capabilitiesGroups
        let session = URLSession(configuration: configuration, delegate: NCCommunicationBackground.shared, delegateQueue: OperationQueue.main)
        return session
    }()
    #endif
    
    //MARK: - init
    
    override init() {
        super.init()
        
        _ = sessionManagerBackground
        _ = sessionManagerBackgroundWWan
        #if EXTENSION
        _ = sessionIdentifierBackgroundExtension
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
                NCContentPresenter.shared.messageNotification("_network_not_available_", description: nil, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: -1009)
            }
            lastReachability = false
        }
        
        NotificationCenter.default.postOnMainThread(name: k_notificationCenter_setTitleMain)
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
    
    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String) {
        delegate?.downloadComplete?(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, description: description, task: task, errorCode: errorCode, errorDescription: errorDescription)
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
    
    @objc func wrtiteCertificate(directoryCertificate: String) {
        
        let certificateAtPath = directoryCertificate + "/tmp.der"
        let certificateToPath = directoryCertificate + "/" + CCUtility.getTimeIntervalSince197() + ".der"
        
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
        
    //MARK: - Download
    
    @objc func cancelDownload(ocId: String, serverUrl:String, fileNameView: String) {
        
        guard let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView) else { return }
        
        if let request = downloadRequest[fileNameLocalPath] {
            request.cancel()
        } else {
            if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
                NCManageDatabase.sharedInstance.setMetadataSession(ocId: ocId, session: "", sessionError: "", sessionSelector: "", sessionTaskIdentifier: 0, status: Int(k_metadataStatusNormal))
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_downloadCancelFile, userInfo: ["metadata":metadata])
            }
        }
    }
    
    @objc func download(metadata: tableMetadata, selector: String, setFavorite: Bool = false, completion: @escaping (_ errorCode: Int)->()) {
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
        
        if NCManageDatabase.sharedInstance.getMetadataFromOcId(metadata.ocId) == nil {
            NCManageDatabase.sharedInstance.addMetadata(tableMetadata.init(value: metadata))
        }
            
        if metadata.status == Int(k_metadataStatusInDownload) || metadata.status == Int(k_metadataStatusDownloading) { return }
                
        NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: NCCommunicationCommon.shared.sessionIdentifierDownload, sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: Int(k_metadataStatusInDownload))
                    
        NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { (request) in
            
            self.downloadRequest[fileNameLocalPath] = request
            
            NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, status: Int(k_metadataStatusDownloading))
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_downloadStartFile, userInfo: ["metadata":metadata])
            
        }, progressHandler: { (progress) in
            
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_progressTask, object: nil, userInfo: ["account":metadata.account, "ocId":metadata.ocId, "serverUrl":metadata.serverUrl, "status":NSNumber(value: k_metadataStatusInDownload), "progress":NSNumber(value: progress.fractionCompleted), "totalBytes":NSNumber(value: progress.totalUnitCount), "totalBytesExpected":NSNumber(value: progress.completedUnitCount)])
            
        }) { (account, etag, date, length, error, errorCode, errorDescription) in
                       
            if error?.isExplicitlyCancelledError ?? false {
                            
                NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: Int(k_metadataStatusNormal))
            
            } else if errorCode == 0 {
               
                NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: selector, sessionTaskIdentifier: 0, status: Int(k_metadataStatusNormal), etag: etag, setFavorite: setFavorite)
                NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                
                #if !EXTENSION
                if let result = NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@", metadata.fileName, metadata.serverUrl)) {
                    
                    NCEndToEndEncryption.sharedManager()?.decryptFileName(metadata.fileName, fileNameView: metadata.fileNameView, ocId: metadata.ocId, key: result.key, initializationVector: result.initializationVector, authenticationTag: result.authenticationTag)
                }
                #endif
                                
            } else {
                                
                NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: errorDescription, sessionSelector: selector, sessionTaskIdentifier: 0, status: Int(k_metadataStatusDownloadError))
                
                #if !EXTENSION
                if errorCode == 401 || errorCode == 403 {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: metadata.account)
                } else if errorCode == Int(CFNetworkErrors.cfurlErrorServerCertificateUntrusted.rawValue) {
                    CCUtility.setCertificateError(metadata.account, error: true)
                }
                #endif
            }
            
            self.downloadRequest[fileNameLocalPath] = nil
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_downloadedFile, userInfo: ["metadata":metadata, "selector":selector, "errorCode":errorCode, "errorDescription":errorDescription])
            
            completion(errorCode)
        }
    }
    
    //MARK: - Upload

    @objc func upload(metadata: tableMetadata, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->())  {
           
        guard let account = NCManageDatabase.sharedInstance.getAccount(predicate: NSPredicate(format: "account == %@", metadata.account)) else {
            NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            
            completion(Int(k_CCErrorInternalError), "Internal error")
            return
        }
        
        var e2eEncrypted = false
        let internalContenType = NCCommunicationCommon.shared.getInternalContenType(fileName: metadata.fileNameView, contentType: metadata.contentType, directory: false)
        var fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                   
        if CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase) {
            e2eEncrypted = true
        }
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            let metadata = tableMetadata.init(value: metadata)
            
            metadata.contentType = internalContenType.contentType
            metadata.iconName = internalContenType.iconName
            metadata.typeFile = internalContenType.typeFile
            if let date = NCUtilityFileSystem.shared.getFileCreationDate(filePath: fileNameLocalPath) {
                 metadata.creationDate = date
            }
            if let date =  NCUtilityFileSystem.shared.getFileModificationDate(filePath: fileNameLocalPath) {
                metadata.date = date
            }
            metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: fileNameLocalPath)
               
            NCManageDatabase.sharedInstance.addMetadata(metadata)
           
            if e2eEncrypted {
                #if !EXTENSION
                NCNetworkingE2EE.shared.upload(metadata: metadata, account: account, completion: completion)
                #endif
            } else if metadata.session == NCCommunicationCommon.shared.sessionIdentifierUpload {
                uploadFile(metadata: metadata, account: account, completion: completion)
            } else {
                uploadFileInBackground(metadata: metadata, account: account, completion: completion)
            }
           
        } else {
               
            CCUtility.extractImageVideoFromAssetLocalIdentifier(forUpload: metadata, notification: true) { (extractMetadata, fileNamePath) in
                   
                guard let extractMetadata = extractMetadata else {
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    completion(Int(k_CCErrorInternalError), "Internal error")
                    return
                }
                       
                fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(extractMetadata.ocId, fileNameView: extractMetadata.fileNameView)
                NCUtilityFileSystem.shared.moveFileInBackground(atPath: fileNamePath!, toPath: fileNameLocalPath)

                NCManageDatabase.sharedInstance.addMetadata(extractMetadata)
               
                if e2eEncrypted {
                    #if !EXTENSION
                    NCNetworkingE2EE.shared.upload(metadata: extractMetadata, account: account, completion: completion)
                    #endif
                } else if metadata.session == NCCommunicationCommon.shared.sessionIdentifierUpload {
                    self.uploadFile(metadata: extractMetadata, account: account, completion: completion)
                } else {
                    self.uploadFileInBackground(metadata: extractMetadata, account: account, completion: completion)
                }
            }
        }
    }
    
    private func uploadFile(metadata: tableMetadata, account: tableAccount, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let metadata = tableMetadata.init(value: metadata)
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        var task: URLSessionTask?
        let description = metadata.ocId
        
        NCCommunication.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, customUserAgent: nil, addCustomHeaders: nil, requestHandler: { (request) in
            
            self.uploadRequest[fileNameLocalPath] = request
            
        }, progressHandler: { (progress) in
            
            if task == nil && self.uploadRequest[fileNameLocalPath]?.task != nil {
                task = self.uploadRequest[fileNameLocalPath]?.task
                NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task!.taskIdentifier, status: Int(k_metadataStatusUploading))
                #if !EXTENSION
                CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, typeFile: metadata.typeFile)
                #endif
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_uploadStartFile, userInfo: ["metadata":metadata])
            }
            
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_progressTask, userInfo: ["account":metadata.account, "ocId":metadata.ocId, "serverUrl":metadata.serverUrl, "status":NSNumber(value: k_metadataStatusInUpload), "progress":NSNumber(value: progress.fractionCompleted), "totalBytes":NSNumber(value: progress.totalUnitCount), "totalBytesExpected":NSNumber(value: progress.completedUnitCount)])
            
        }) { (account, ocId, etag, date, size, error, errorCode, errorDescription) in
         
            self.uploadRequest[fileNameLocalPath] = nil
            self.uploadComplete(fileName: metadata.fileName, serverUrl: metadata.serverUrl, ocId: ocId, etag: etag, date: date, size: size, description: description, task: task!, errorCode: errorCode, errorDescription: errorDescription)
            
            completion(errorCode, errorDescription)
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
        
        if let task = NCCommunicationBackground.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, description: metadata.ocId, session: session!) {
                     
            NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task.taskIdentifier, status: Int(k_metadataStatusUploading))
            
            #if !EXTENSION
            CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, typeFile: metadata.typeFile)
            #endif
            
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_uploadStartFile, userInfo: ["metadata":metadata])
            
            completion(0, "")
            
        } else {
            
            NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            completion(Int(k_CCErrorInternalError), "task null")
        }
    }
    
    func uploadProgress(_ progress: Double, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.uploadProgress?(progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected, fileName: fileName, serverUrl: serverUrl, session: session, task: task)
        
        var metadata: tableMetadata?
        let description: String = task.taskDescription ?? ""
        
        if let metadataTmp = self.uploadMetadataInBackground[fileName+serverUrl] {
            metadata = metadataTmp
        } else if let metadataTmp = NCManageDatabase.sharedInstance.getMetadataFromOcId(description){
            self.uploadMetadataInBackground[fileName+serverUrl] = metadataTmp
            metadata = metadataTmp
        }
        
        if metadata != nil {
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_progressTask, userInfo: ["account":metadata!.account, "ocId":metadata!.ocId, "serverUrl":serverUrl, "status":NSNumber(value: k_metadataStatusInUpload), "progress":NSNumber(value: progress), "totalBytes":NSNumber(value: totalBytes), "totalBytesExpected":NSNumber(value: totalBytesExpected)])
        }
    }
    
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String) {
        if delegate != nil {
            delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size:size, description: description, task: task, errorCode: errorCode, errorDescription: errorDescription)
        } else {
            
            guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(description) else { return }
            guard let tableAccount = NCManageDatabase.sharedInstance.getAccount(predicate: NSPredicate(format: "account == %@", metadata.account)) else { return }
            let ocIdTemp = metadata.ocId
            
            if errorCode == 0 && ocId != nil {
                
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
                metadata.status = Int(k_metadataStatusNormal)
                
                // Delete Asset on Photos album
                if tableAccount.autoUploadDeleteAssetLocalIdentifier && metadata.assetLocalIdentifier != "" && metadata.sessionSelector == selectorUploadAutoUpload {
                    metadata.deleteAssetLocalIdentifier = true;
                }
                
                if CCUtility.getDisableLocalCacheAfterUpload() {
                    CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } else {
                    NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                }
                NCManageDatabase.sharedInstance.addMetadata(metadata)
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
                
                #if !EXTENSION
                self.getOcIdInBackgroundSession { (listOcId) in
                    if listOcId.count == 0 && self.uploadRequest.count == 0 {
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        appDelegate.networkingAutoUpload.startProcess()
                    }
                }
                #endif                
                
                NCCommunicationCommon.shared.writeLog("Upload complete " + serverUrl + "/" + fileName + ", result: success(\(size) bytes)")
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_uploadedFile, userInfo: ["metadata":metadata, "ocIdTemp":ocIdTemp, "errorCode":errorCode, "errorDescription":""])
                
            } else {
                
                if errorCode == NSURLErrorCancelled {
                
                    if metadata.status == k_metadataStatusUploadForcedStart {
                        
                        NCManageDatabase.sharedInstance.setMetadataSession(ocId: ocId!, session: sessionIdentifierBackground, sessionError: "", sessionTaskIdentifier: 0, status: Int(k_metadataStatusInUpload))
                        NCNetworking.shared.upload(metadata: metadata) { (_, _) in }
                                                
                    } else {
                        
                        CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    }
                    
                    NotificationCenter.default.postOnMainThread(name: k_notificationCenter_uploadCancelFile, userInfo: ["metadata":metadata])
                
                } else if errorCode == 401 || errorCode == 403 {
                    
                    #if !EXTENSION
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: metadata.account)
                    #endif
                    
                    NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: Int(k_metadataStatusUploadError))

                } else if errorCode == Int(CFNetworkErrors.cfurlErrorServerCertificateUntrusted.rawValue) {
                    
                    CCUtility.setCertificateError(metadata.account, error: true)
                    NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: Int(k_metadataStatusUploadError))

                } else {
                    
                    NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: Int(k_metadataStatusUploadError))
                }
                
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_uploadedFile, userInfo: ["metadata":metadata, "ocIdTemp":ocIdTemp, "errorCode":errorCode, "errorDescription":""])
            }
            
            // Delete
            self.uploadMetadataInBackground[fileName+serverUrl] = nil
        }
    }
    
    @objc func verifyUploadZombie() {
        
        var session: URLSession?
        
        // verify k_metadataStatusInUpload (BACKGROUND)
        let metadatasInUploadBackground = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d AND sessionTaskIdentifier == 0", sessionIdentifierBackground, sessionIdentifierBackgroundExtension, sessionIdentifierBackgroundWWan, k_metadataStatusInUpload))
        for metadata in metadatasInUploadBackground {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d AND sessionTaskIdentifier == 0", metadata.ocId, k_metadataStatusInUpload)) {
                    NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: self.sessionIdentifierBackground, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: 0, status: Int(k_metadataStatusWaitUpload))
                }
            }
        }
        
        // k_metadataStatusUploading (BACKGROUND)
        let metadatasUploadingBackground = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d", sessionIdentifierBackground, sessionIdentifierBackgroundWWan, sessionIdentifierBackgroundExtension, k_metadataStatusUploading))
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
                    if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d", metadata.ocId, k_metadataStatusUploading)) {
                        NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: self.sessionIdentifierBackground, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: 0, status: Int(k_metadataStatusWaitUpload))
                    }
                }
            })
        }
        
        // k_metadataStatusUploading
        let metadatasUploading = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", NCCommunicationCommon.shared.sessionIdentifierUpload, k_metadataStatusUploading))
        for metadata in metadatasUploading {
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            if uploadRequest[fileNameLocalPath] == nil {
                NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: "", sessionSelector: nil, sessionTaskIdentifier: 0, status: Int(k_metadataStatusWaitUpload))
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
            NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_uploadCancelFile, userInfo: ["metadata":metadata])
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
        
        session!.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) in
            
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
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    NotificationCenter.default.postOnMainThread(name: k_notificationCenter_uploadCancelFile, userInfo: ["metadata":metadata])
                }
            }
            completion()
        }
    }
    
    @objc func cancelAllTransfer(account: String, completion: @escaping ()->()) {
       
        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "status == %d OR status == %d", account, k_metadataStatusWaitUpload, k_metadataStatusUploadError))
        
        let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "status != %d", k_metadataStatusNormal), sorted: "fileName", ascending: true)
        
        var counter = 0
        for metadata in metadatas {
            counter += 1

            if (metadata.status == k_metadataStatusWaitDownload || metadata.status == k_metadataStatusDownloadError) {
                
                NCManageDatabase.sharedInstance.setMetadataSession(ocId: metadata.ocId, session: "", sessionError: "", sessionSelector: "", sessionTaskIdentifier: 0, status: Int(k_metadataStatusNormal))
            }
            
            if metadata.status == k_metadataStatusDownloading || metadata.status == k_metadataStatusUploading {
                
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
                              
                NCManageDatabase.sharedInstance.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: true, account: account) { (metadataFolder, metadatasFolder, metadatas) in
                    
                    // Update directory
                    NCManageDatabase.sharedInstance.addDirectory(encrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, serverUrl: serverUrl, richWorkspace: metadataFolder.richWorkspace, creationDate: metadataFolder.creationDate, account: metadataFolder.account)
                    
                    // Update sub directories
                    for metadata in metadatasFolder {
                        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                        NCManageDatabase.sharedInstance.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, richWorkspace: metadata.richWorkspace, creationDate: metadata.creationDate, account: account)
                    }
                    
                    let metadatasResult = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, k_metadataStatusNormal))
                    let metadatasChanged = NCManageDatabase.sharedInstance.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareEtagLocal: true)
                        
                    if metadatasChanged.metadatasUpdate.count > 0 {
                        NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["serverUrl":serverUrl])
                    }
                    
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
                let metadata = NCManageDatabase.sharedInstance.convertNCFileToMetadata(file, isEncrypted: isEncrypted, account: account)
                
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
                
                NCManageDatabase.sharedInstance.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: false, account: account) { (metadataFolder, metadatasFolder, metadatas) in
                    
                    // Update sub directories
                    for metadata in metadatasFolder {
                        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                        NCManageDatabase.sharedInstance.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, richWorkspace: metadata.richWorkspace, account: account)
                    }
                    
                    NCManageDatabase.sharedInstance.addMetadatas(metadatas)
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
            fileNameFolder = NCUtility.shared.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
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
                        
                            NCManageDatabase.sharedInstance.addMetadata(metadata)
                            NCManageDatabase.sharedInstance.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: fileNameFolderUrl, richWorkspace: metadata.richWorkspace, creationDate: metadata.creationDate, account: account)
                        }
                        
                        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(metadataFolder?.ocId) {
                            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_createFolder, userInfo: ["metadata": metadata])
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
    
    @objc func createFolder(assets: [PHAsset], selector: String, useSubFolder: Bool, account: String, urlBase: String) -> Bool {
        
        let serverUrl = NCManageDatabase.sharedInstance.getAccountAutoUploadDirectory(urlBase: urlBase, account: account)
        let fileName =  NCManageDatabase.sharedInstance.getAccountAutoUploadFileName()
        let autoUploadPath = NCManageDatabase.sharedInstance.getAccountAutoUploadPath(urlBase: urlBase, account: account)
        var error = false
        
        error = createFolderWithSemaphore(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase)
        if useSubFolder && !error {
            for dateSubFolder in CCUtility.createNameSubFolder(assets) {
                let fileName = (dateSubFolder as! NSString).lastPathComponent
                let serverUrl = ((autoUploadPath + "/" + (dateSubFolder as! String)) as NSString).deletingLastPathComponent
                error = createFolderWithSemaphore(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase)
                if error { break }
            }
        }
        
        return error
    }
    
    private func createFolderWithSemaphore(fileName: String, serverUrl: String, account: String, urlBase: String) -> Bool {
        var error = false
        let semaphore = Semaphore()
        NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, overwrite: true) { (errorCode, errorDescription) in
            if errorCode != 0 { error = true }
            semaphore.continue()
        }
        if semaphore.wait() != .success { error = true }
        return error
    }
    
    //MARK: - WebDav Delete

    @objc func deleteMetadata(_ metadata: tableMetadata, account: String, urlBase: String, onlyLocal: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
                
        if (onlyLocal) {
            
            NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NCUtilityFileSystem.shared.deleteFile(filePath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
            
            if let metadataLivePhoto = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) {
                NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadataLivePhoto.ocId))
                NCUtilityFileSystem.shared.deleteFile(filePath: CCUtility.getDirectoryProviderStorageOcId(metadataLivePhoto.ocId))
            }
            
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "onlyLocal": true])
            completion(0, "")
            
            return
        }
        
        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: urlBase)
        let metadataLive = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata)
        
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
        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: k_permission_can_delete)
        if metadata.permissions != "" && permission == false {
            
            completion(Int(k_CCErrorInternalError), "_no_permission_delete_file_")
            return
        }
                
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCCommunication.shared.deleteFileOrFolder(serverUrlFileName, customUserAgent: nil, addCustomHeaders: addCustomHeaders) { (account, errorCode, errorDescription) in
        
            if errorCode == 0 || errorCode == 404 {
                
                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }
                                       
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

                if metadata.directory {
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
                }
                
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "onlyLocal": false])
            }
            
            completion(errorCode, errorDescription)
        }
    }
    
    //MARK: - WebDav Favorite

    @objc func favoriteMetadata(_ metadata: tableMetadata, urlBase: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        if let metadataLive = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) {
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
        
        NCCommunication.shared.setFavorite(fileName: fileName, favorite: favorite) { (account, errorCode, errorDescription) in
    
            if errorCode == 0 && metadata.account == account {
                
                NCManageDatabase.sharedInstance.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite)
                
                #if !EXTENSION
                if favorite {
                    if CCUtility.getFavoriteOffline() {
                        NCOperationQueue.shared.synchronizationMetadata(metadata, selector: selectorDownloadAllFile)
                    } else {
                        NCOperationQueue.shared.synchronizationMetadata(metadata, selector: selectorReadFile)
                    }
                }
                #endif
                
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_favoriteFile, userInfo: ["metadata": metadata])
            }
            
            completion(errorCode, errorDescription)
        }
    }
    
    @objc func listingFavoritescompletion(selector: String, completion: @escaping (_ account: String, _ metadatas: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String)->()) {
        NCCommunication.shared.listingFavorites(showHiddenFiles: CCUtility.getShowHiddenFiles()) { (account, files, errorCode, errorDescription) in
            if errorCode == 0 {
                NCManageDatabase.sharedInstance.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: false, account: account) { (_, _, metadatas) in
                    if selector != selectorListingFavorite {
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
        let metadataLive = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata)
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
        
        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            completion(Int(k_CCErrorInternalError), "_no_permission_modify_file_")
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
                
        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false) { (account, errorCode, errorDescription) in
                    
            if errorCode == 0 {
                        
                NCManageDatabase.sharedInstance.renameMetadata(fileNameTo: fileNameNew, ocId: metadata.ocId)
                        
                if metadata.directory {
                            
                    let serverUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
                    let serverUrlTo = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: fileNameNew)!
                    if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                                
                        NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, serverUrlTo: serverUrlTo, etag: "", ocId: nil, fileId: nil, encrypted: directory.e2eEncrypted, richWorkspace: nil, account: metadata.account)
                    }
                            
                } else {
                            
                    NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, fileName: fileNameNew, etag: nil)
                    // Move file system
                    let atPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                    let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
                    do {
                        try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                    } catch { }
                }
                
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata])
                
            }
                    
            completion(errorCode, errorDescription)
        }
    }
    
    //MARK: - WebDav Move
    
    @objc func moveMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        if let metadataLive = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) {
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
    
        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            completion(Int(k_CCErrorInternalError), "_no_permission_modify_file_")
            return
        }
        
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
        
        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite) { (account, errorCode, errorDescription) in
                                
            if errorCode == 0 {
    
                if metadata.directory {
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: account)
                }
                
                NCManageDatabase.sharedInstance.moveMetadata(ocId: metadata.ocId, serverUrlTo: serverUrlTo)
                guard let metadataNew = NCManageDatabase.sharedInstance.getMetadataFromOcId(metadata.ocId) else { return }

                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_moveFile, userInfo: ["metadata": metadata, "metadataNew": metadataNew])
                
            }
            
            completion(errorCode, errorDescription)
        }
    }
    
    //MARK: - WebDav Copy
    
    @objc func copyMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        if let metadataLive = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) {
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
    
        let permission = NCUtility.shared.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            completion(Int(k_CCErrorInternalError), "_no_permission_modify_file_")
            return
        }
        
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
        
        NCCommunication.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite) { (account, errorCode, errorDescription) in
                   
            if errorCode == 0 {
                
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_copyFile, userInfo: ["metadata": metadata, "serverUrlTo": serverUrlTo])
            }
            
            completion(errorCode, errorDescription)
        }
    }
}
