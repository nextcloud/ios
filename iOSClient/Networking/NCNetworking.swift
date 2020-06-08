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
    var downloadRequest = [String:DownloadRequest]()
    var uploadRequest = [String:UploadRequest]()

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
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: k_notificationCenter_setTitleMain), object: nil, userInfo: nil)
        #endif
    }
    
    func authenticationChallenge(_ challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if NCNetworking.shared.checkTrustedChallenge(challenge: challenge, directoryCertificate: CCUtility.getDirectoryCerificates()) {
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
    
    @objc func cancelDownload(metadata: tableMetadata) {
        
        guard let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName) else { return }
        
        if let request = downloadRequest[fileNameLocalPath] {
            request.cancel()
        } else {
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                
                metadata.session = ""
                metadata.sessionError = ""
                metadata.status = Int(k_metadataStatusNormal)
                
                NCManageDatabase.sharedInstance.addMetadata(metadata)
                
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["ocId":metadata.ocId,"serverUrl":metadata.serverUrl])
            }
        }
    }
    
    @objc func download(metadata: tableMetadata, selector: String, setFavorite: Bool = false, completion: @escaping (_ errorCode: Int)->()) {
        
        var metadata = metadata
        let serverUrl = metadata.serverUrl
        let serverUrlFileName = serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
        
        if metadata.status == Int(k_metadataStatusInDownload) || metadata.status == Int(k_metadataStatusDownloading) { return }
        
        metadata.status = Int(k_metadataStatusInDownload)
        metadata.session = NCCommunicationCommon.shared.sessionIdentifierDownload
        if let result = NCManageDatabase.sharedInstance.addMetadata(metadata) { metadata = result }
        
        NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["ocId":metadata.ocId,"serverUrl":metadata.serverUrl])
                
        NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { (request) in
            
            self.downloadRequest[fileNameLocalPath] = request
            metadata.status = Int(k_metadataStatusDownloading)
            if let result = NCManageDatabase.sharedInstance.addMetadata(metadata) { metadata = result }
            
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_downloadFileStart), object: nil, userInfo: ["ocId":metadata.ocId, "serverUrl":serverUrl, "account":metadata.account])
            
        }, progressHandler: { (progress) in
            
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_progressTask), object: nil, userInfo: ["account":metadata.account, "ocId":metadata.ocId, "serverUrl":serverUrl, "status":NSNumber(value: k_metadataStatusInDownload), "progress":NSNumber(value: progress.fractionCompleted), "totalBytes":NSNumber(value: progress.totalUnitCount), "totalBytesExpected":NSNumber(value: progress.completedUnitCount)])
            
        }) { (account, etag, date, length, error, errorCode, errorDescription) in
                        
            self.downloadRequest[fileNameLocalPath] = nil
           
            if errorCode == 0 {
               
                metadata.date = date ?? NSDate()
                metadata.etag = etag ?? ""
                if setFavorite { metadata.favorite = true }
                
                metadata.session = ""
                metadata.sessionError = ""
                metadata.status = Int(k_metadataStatusNormal)
                
                NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                if let result = NCManageDatabase.sharedInstance.addMetadata(metadata) { metadata = result }

                #if !EXTENSION
                if let result = NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@", metadata.fileName, serverUrl)) {
                    
                    NCEndToEndEncryption.sharedManager()?.decryptFileName(metadata.fileName, fileNameView: metadata.fileNameView, ocId: metadata.ocId, key: result.key, initializationVector: result.initializationVector, authenticationTag: result.authenticationTag)
                }
                #endif
                                
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_downloadedFile), object: nil, userInfo: ["metadata":metadata, "selector":selector, "errorCode":errorCode, "errorDescription":errorDescription])
                
            } else if error?.isExplicitlyCancelledError ?? false {
                                
                metadata.session = ""
                metadata.sessionError = ""
                metadata.status = Int(k_metadataStatusNormal)
                
                if let result = NCManageDatabase.sharedInstance.addMetadata(metadata) { metadata = result }
            
            } else {
                
                metadata.session = ""
                metadata.sessionError = errorDescription
                metadata.status = Int(k_metadataStatusDownloadError)
                
                if let result = NCManageDatabase.sharedInstance.addMetadata(metadata) { metadata = result }

                #if !EXTENSION
                if errorCode == 401 || errorCode == 403 {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: metadata.account)
                } else if errorCode == Int(CFNetworkErrors.cfurlErrorServerCertificateUntrusted.rawValue) {
                    CCUtility.setCertificateError(metadata.account, error: true)
                }
                #endif
                
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_downloadedFile), object: nil, userInfo: ["metadata":metadata, "selector":selector, "errorCode":errorCode, "errorDescription":errorDescription])
            }
            
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["ocId":metadata.ocId,"serverUrl":metadata.serverUrl])
            
            completion(errorCode)
        }
    }
    
    //MARK: - Upload

    @objc func cancelUpload(metadata: tableMetadata) {
        
        guard let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName) else { return }
        
        if let request = uploadRequest[fileNameLocalPath] {
            request.cancel()
        } else {
            CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
            NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["serverUrl":metadata.serverUrl])
        }
    }
    
    @objc func upload(metadata: tableMetadata) {
           
        var metadataForUpload: tableMetadata?
        var e2eEncrypted = false
        let internalContenType = NCCommunicationCommon.shared.getInternalContenType(fileName: metadata.fileNameView, contentType: metadata.contentType, directory: false)
        var fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
           
        guard let account = NCManageDatabase.sharedInstance.getAccount(predicate: NSPredicate(format: "account == %@", metadata.account)) else {
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_uploadedFile), object: nil, userInfo: ["metadata":metadata, "errorCode":k_CCErrorInternalError, "errorDescription":"Internal error"])
            return
        }
           
        if CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account) {
            e2eEncrypted = true
        }
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {

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
               
            if metadata.size > Double(k_max_filesize_E2EE) {
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_uploadedFile), object: nil, userInfo: ["metadata":metadata, "errorCode":k_CCErrorInternalError, "errorDescription":"E2E Error file too big"])
                return
            }
               
            metadataForUpload = NCManageDatabase.sharedInstance.addMetadata(metadata)
           
            if e2eEncrypted {
                #if !EXTENSION
                NCNetworkingE2EE.shared.upload(metadata: metadataForUpload!, account: account)
                #endif
            } else {
                uploadFile(metadata: metadataForUpload!, account: account)
            }
           
        } else {
               
            CCUtility.extractImageVideoFromAssetLocalIdentifier(forUpload: metadata, notification: true) { (extractMetadata, fileNamePath) in
                   
                guard let extractMetadata = extractMetadata else {
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    return
                }
                       
                fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(extractMetadata.ocId, fileNameView: extractMetadata.fileNameView)
                CCUtility.moveFile(atPath: fileNamePath, toPath: fileNameLocalPath)

                if e2eEncrypted && (extractMetadata.size > Double(k_max_filesize_E2EE)) {
                    NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_uploadedFile), object: nil, userInfo: ["metadata":metadata, "errorCode":k_CCErrorInternalError, "errorDescription":"E2E Error file too big"])
                    return
                }
                       
                metadataForUpload = NCManageDatabase.sharedInstance.addMetadata(extractMetadata)
               
                if e2eEncrypted {
                    #if !EXTENSION
                    NCNetworkingE2EE.shared.upload(metadata: metadataForUpload!, account: account)
                    #endif
                } else {
                    self.uploadFile(metadata: metadataForUpload!, account: account)
                }
            }
        }
    }
    
    private func uploadFile(metadata: tableMetadata, account: tableAccount) {
        
        var session: URLSession?
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        
        if metadata.session == NCCommunicationCommon.shared.sessionIdentifierBackground || metadata.session == NCCommunicationCommon.shared.sessionIdentifierExtension {
            session = NCCommunicationBackground.shared.sessionManagerTransfer
        } else if metadata.session == NCCommunicationCommon.shared.sessionIdentifierBackgroundWWan {
            session = NCCommunicationBackground.shared.sessionManagerTransferWWan
        }
        
        if let task = NCCommunicationBackground.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, description: "", session: session!) {
         
            metadata.status = Int(k_metadataStatusUploading)
            metadata.sessionError = ""
            metadata.sessionTaskIdentifier = task.taskIdentifier
            NCManageDatabase.sharedInstance.addMetadata(metadata)
            
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_uploadFileStart), object: nil, userInfo: ["ocId":metadata.ocId, "task":task, "serverUrl":metadata.serverUrl, "account":metadata.account])
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["ocId":metadata.ocId,"serverUrl":metadata.serverUrl])
        }
    }
    
    func uploadProgress(_ progress: Double, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.uploadProgress?(progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected, fileName: fileName, serverUrl: serverUrl, session: session, task: task)
        
        if let metadata = NCManageDatabase.sharedInstance.getMetadataInSessionFromFileName(fileName, serverUrl: serverUrl, taskIdentifier: task.taskIdentifier) {
                        
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_progressTask), object: nil, userInfo: ["account":metadata.account, "ocId":metadata.ocId, "serverUrl":serverUrl, "status":NSNumber(value: k_metadataStatusInUpload), "progress":NSNumber(value: progress), "totalBytes":NSNumber(value: totalBytes), "totalBytesExpected":NSNumber(value: totalBytesExpected)])
        }
    }
    
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, errorCode: Int, errorDescription: String) {
        if delegate != nil {
            delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size:size, description: description, task: task, errorCode: errorCode, errorDescription: errorDescription)
        } else {
            
            guard var metadata = NCManageDatabase.sharedInstance.getMetadataInSessionFromFileName(fileName, serverUrl: serverUrl, taskIdentifier: task.taskIdentifier) else {
                return
            }
            
            if errorCode == 0 && ocId != nil {
                
                CCUtility.moveFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), toPath:  CCUtility.getDirectoryProviderStorageOcId(ocId))
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    
                metadata.date = date ?? NSDate()
                metadata.etag = etag ?? ""
                metadata.ocId = ocId!
                
                metadata.session = ""
                metadata.sessionError = ""
                metadata.sessionTaskIdentifier = 0
                metadata.status = Int(k_metadataStatusNormal)
                        
                if let result = NCManageDatabase.sharedInstance.addMetadata(metadata) { metadata = result }

                if CCUtility.getDisableLocalCacheAfterUpload() {
                    CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } else {
                    NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                }
                
                #if !EXTENSION
                CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, filterGrayScale: false, typeFile: metadata.typeFile, writeImage: true)
                
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_uploadedFile), object: nil, userInfo: ["metadata":metadata, "errorCode":errorCode, "errorDescription":""])
                #endif
                
            } else if errorCode == NSURLErrorCancelled {
                
                if metadata.status == k_metadataStatusUploadForcedStart {
                    
                    metadata.session = NCCommunicationCommon.shared.sessionIdentifierBackground
                    metadata.sessionError = ""
                    metadata.sessionTaskIdentifier = 0
                    metadata.status = Int(k_metadataStatusInUpload)
                    
                    if let result = NCManageDatabase.sharedInstance.addMetadata(metadata) { metadata = result }
                    NCNetworking.shared.upload(metadata: metadata)
                        
                } else {
                    
                    CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                }
                
            } else if errorCode == 401 || errorCode == 403 {
                
                #if !EXTENSION
                NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: metadata.account)
                #endif
                
                CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                
            } else if errorCode == Int(CFNetworkErrors.cfurlErrorServerCertificateUntrusted.rawValue) {
                
                CCUtility.setCertificateError(metadata.account, error: true)
                
                CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                                        
            } else {
                
                metadata.session = ""
                metadata.sessionError = errorDescription
                metadata.sessionTaskIdentifier = 0
                metadata.status = Int(k_metadataStatusUploadError)
                
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_uploadedFile), object: nil, userInfo: ["metadata":metadata, "errorCode":errorCode, "errorDescription":errorDescription])
                
                if let result = NCManageDatabase.sharedInstance.addMetadata(metadata) { metadata = result }
            }
            
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["ocId":metadata.ocId,"serverUrl":metadata.serverUrl])
        }
    }
    
    //MARK: - Download / Upload
    
    @objc func verifyTransfer() {
        
        var session: URLSession?
        
        // download
        if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "status == %d", Int(k_metadataStatusDownloading)), sorted: nil, ascending: true) {
            for metadata in metadatas {
                guard let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName) else { continue }
                let request = downloadRequest[fileNameLocalPath]
                if request == nil {
                    metadata.session = ""
                    metadata.sessionError = ""
                    metadata.status = Int(k_metadataStatusNormal)
                    NCManageDatabase.sharedInstance.addMetadata(metadata)
                    
                    NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["ocId":metadata.ocId,"serverUrl":metadata.serverUrl])
                }
            }
        }
        
        // upload
        if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", NCCommunicationCommon.shared.sessionIdentifierUpload ,Int(k_metadataStatusUploading)), sorted: nil, ascending: true) {
            for metadata in metadatas {
                guard let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName) else { continue }
                let request = uploadRequest[fileNameLocalPath]
                if request == nil {
                    CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    
                    NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["serverUrl":metadata.serverUrl])
                }
            }
        }
        
        // k_metadataStatusUploading (BACKGROUND)
        let sessionBackground = NCCommunicationCommon.shared.sessionIdentifierBackground
        let sessionBackgroundWWan = NCCommunicationCommon.shared.sessionIdentifierBackgroundWWan
        if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@) AND status == %d", sessionBackground, sessionBackgroundWWan, k_metadataStatusUploading), sorted: nil, ascending: true) {
        
            for metadata in metadatas {
                
                if metadata.session == NCCommunicationCommon.shared.sessionIdentifierBackground {
                    session = NCCommunicationBackground.shared.sessionManagerTransfer
                } else if metadata.session == NCCommunicationCommon.shared.sessionIdentifierBackgroundWWan {
                    session = NCCommunicationBackground.shared.sessionManagerTransferWWan
                } else if metadata.session == NCCommunicationCommon.shared.sessionIdentifierExtension {
                    session = NCCommunicationBackground.shared.sessionManagerTransferExtension
                }
                
                var findTask = false
                
                session?.getAllTasks(completionHandler: { (tasks) in
                    for task in tasks {
                        if task.taskIdentifier == metadata.sessionTaskIdentifier {
                            findTask = true
                        }
                    }
                    
                    if !findTask {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d", metadata.ocId, k_metadataStatusUploading)) {
                                    
                                metadata.session = NCCommunicationCommon.shared.sessionIdentifierBackground
                                metadata.sessionError = ""
                                metadata.sessionTaskIdentifier = 0
                                metadata.status = Int(k_metadataStatusWaitUpload)
                                    
                                NCManageDatabase.sharedInstance.addMetadata(metadata)
                            }
                        }
                    }
                })
            }
        }
        
        // verify k_metadataStatusInUpload (BACKGROUND)
        if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@) AND status == %d AND sessionTaskIdentifier == 0", sessionBackground, sessionBackgroundWWan, k_metadataStatusInUpload), sorted: nil, ascending: true) {
            
            for metadata in metadatas {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d AND sessionTaskIdentifier == 0", metadata.ocId, k_metadataStatusInUpload)) {
                       
                        metadata.session = NCCommunicationCommon.shared.sessionIdentifierBackground
                        metadata.sessionError = ""
                        metadata.sessionTaskIdentifier = 0
                        metadata.status = Int(k_metadataStatusWaitUpload)
                            
                        NCManageDatabase.sharedInstance.addMetadata(metadata)
                    }
                }
            }
        }
    }
    
    //MARK: - WebDav Read file, folder
    
    @objc func readFolder(serverUrl: String, account: String, completion: @escaping (_ account: String, _ metadataFolder: tableMetadata?, _ metadatas: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String)->()) {
        
        NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: CCUtility.getShowHiddenFiles()) { (account, files, errorCode, errorDescription) in
            
            if errorCode == 0 && files != nil {
                              
                NCManageDatabase.sharedInstance.convertNCCommunicationFilesToMetadatas(files!, useMetadataFolder: true, account: account) { (metadataFolder, metadatasFolder, metadatas) in
                    
                    // Add directory
                    NCManageDatabase.sharedInstance.addDirectory(encrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, serverUrl: serverUrl, richWorkspace: metadataFolder.richWorkspace, account: account)
                    
                    // Add other directories
                    for metadata in metadatasFolder {
                       let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                       NCManageDatabase.sharedInstance.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, richWorkspace: metadata.richWorkspace, account: account)
                    }
                    
                    // Save status transfer metadata
                    let metadatasInDownload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", account, serverUrl, k_metadataStatusWaitDownload, k_metadataStatusInDownload, k_metadataStatusDownloading, k_metadataStatusDownloadError), sorted: nil, ascending: false)
                    
                    let metadatasInUpload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", account, serverUrl, k_metadataStatusWaitUpload, k_metadataStatusInUpload, k_metadataStatusUploading, k_metadataStatusUploadError), sorted: nil, ascending: false)

                    // Delete metadata
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, k_metadataStatusNormal))
                    
                    // Add metadata
                    let metadataFolderInserted = NCManageDatabase.sharedInstance.addMetadata(metadataFolder)
                    let metadatasInserted = NCManageDatabase.sharedInstance.addMetadatas(metadatas)
                     
                    if metadatasInDownload != nil {
                        NCManageDatabase.sharedInstance.addMetadatas(metadatasInDownload!)
                    }
                    if metadatasInUpload != nil {
                        NCManageDatabase.sharedInstance.addMetadatas(metadatasInUpload!)
                    }
                    
                    NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["serverUrl":serverUrl])
                    
                    completion(account, metadataFolderInserted, metadatasInserted, errorCode, "")
                }
            
            } else {
                
                #if !EXTENSION
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                #endif
                
                completion(account, nil, nil, errorCode, errorDescription)
            }
        }
    }
    
    @objc func readFile(serverUrlFileName: String, account: String, completion: @escaping (_ account: String, _ metadata: tableMetadata?, _ errorCode: Int, _ errorDescription: String)->()) {
        
        NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles()) { (account, files, errorCode, errorDescription) in

            if errorCode == 0 && files != nil {
                if files?.count ?? 0 == 1 {
                    let file = files![0]
                    let isEncrypted = CCUtility.isFolderEncrypted(file.serverUrl, e2eEncrypted:file.e2eEncrypted, account: account)
                    let metadata = NCManageDatabase.sharedInstance.convertNCFileToMetadata(file, isEncrypted: isEncrypted, account: account)
                    completion(account, metadata, errorCode, "")
                } else {
                    completion(account, nil, errorCode, "")
                }
            } else {

                completion(account, nil, errorCode, errorDescription)
            }
        }
    }
    
    //MARK: - WebDav Create Folder

    @objc func createFolder(fileName: String, serverUrl: String, account: String, url: String, overwrite: Bool = false, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(serverUrl, e2eEncrypted: false, account: account)
               
        if isDirectoryEncrypted {
            #if !EXTENSION
            NCNetworkingE2EE.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: account, url: url, completion: completion)
            #endif
        } else {
            createFolderPlain(fileName: fileName, serverUrl: serverUrl, account: account, url: url, overwrite: overwrite, completion: completion)
        }
    }
    
    @objc func createFolderPlain(fileName: String, serverUrl: String, account: String, url: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        
        if (!overwrite) {
            fileNameFolder = NCUtility.sharedInstance.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        }
        if fileNameFolder.count == 0 {
            self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        let fileNameFolderUrl = serverUrl + "/" + fileNameFolder
        
        NCCommunication.shared.createFolder(fileNameFolderUrl) { (account, ocId, date, errorCode, errorDescription) in
            if errorCode == 0 {
                self.readFile(serverUrlFileName: fileNameFolderUrl, account: account) { (account, metadataFolder, errorCode, errorDescription) in
                    if errorCode == 0 {
                        // Add Metadata
                        NCManageDatabase.sharedInstance.addMetadata(metadataFolder!)
                        // Add folder
                        NCManageDatabase.sharedInstance.addDirectory(encrypted: metadataFolder!.e2eEncrypted, favorite: metadataFolder!.favorite, ocId: metadataFolder!.ocId, fileId: metadataFolder!.fileId, etag: nil, permissions: metadataFolder!.permissions, serverUrl: fileNameFolderUrl, richWorkspace: metadataFolder!.richWorkspace, account: account)
                        
                        self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                        
                    } else {
                        self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                    }
                }
                
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["serverUrl":serverUrl])
                
            } else if errorCode == 405 && overwrite {
                self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": 0], errorDescription: "", completion: completion)
            } else {
                self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
            }
        }
    }
        
    //MARK: - WebDav Delete

    @objc func deleteMetadata(_ metadata: tableMetadata, account: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
                
        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account)
        let metadataLive = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata)
        
        if isDirectoryEncrypted {
            #if !EXTENSION
            if metadataLive == nil {
                NCNetworkingE2EE.shared.deleteMetadata(metadata, url: url, completion: completion)
            } else {
                NCNetworkingE2EE.shared.deleteMetadata(metadataLive!, url: url) { (errorCode, errorDescription) in
                    if errorCode == 0 {
                        NCNetworkingE2EE.shared.deleteMetadata(metadata, url: url, completion: completion)
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
    
    func deleteMetadataPlain(_ metadata: tableMetadata, addCustomHeaders: [String:String]?, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        // verify permission
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_delete)
        if metadata.permissions != "" && permission == false {
            
            self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": Int(k_CCErrorNotPermission)], errorDescription: "_no_permission_delete_file_", completion: completion)
            return
        }
                
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCCommunication.shared.deleteFileOrFolder(serverUrlFileName, customUserAgent: nil, addCustomHeaders: addCustomHeaders) { (account, errorCode, errorDescription) in
        
            if errorCode == 0 || errorCode == 404 {
                
                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }
                                       
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.sharedInstance.deleteMedia(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

                if metadata.directory {
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
                }
                
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["serverUrl":metadata.serverUrl])
            }
            
            self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    //MARK: - WebDav Favorite

    @objc func favoriteMetadata(_ metadata: tableMetadata, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        if let metadataLive = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) {
            favoriteMetadataPlain(metadataLive, url: url) { (errorCode, errorDescription) in
                if errorCode == 0 {
                    self.favoriteMetadataPlain(metadata, url: url, completion: completion)
                } else {
                    completion(errorCode, errorDescription)
                }
            }
        } else {
            favoriteMetadataPlain(metadata, url: url, completion: completion)
        }
    }
    
    @objc func favoriteMetadataPlain(_ metadata: tableMetadata, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: url)!
        let favorite = !metadata.favorite
        
        NCCommunication.shared.setFavorite(fileName: fileName, favorite: favorite) { (account, errorCode, errorDescription) in
    
            if errorCode == 0 && metadata.account == account {
                NCManageDatabase.sharedInstance.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite)
                
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["ocId":metadata.ocId,"serverUrl":metadata.serverUrl])
            }
            
            self.NotificationPost(name: k_notificationCenter_favoriteFile, userInfo: ["metadata": metadata, "favorite": favorite, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    //MARK: - WebDav Rename

    @objc func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, url: String, viewController: UIViewController?, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account)
        let metadataLive = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata)
        let fileNameNewLive = (fileNameNew as NSString).deletingPathExtension + ".mov"

        if isDirectoryEncrypted {
            #if !EXTENSION
            if metadataLive == nil {
                NCNetworkingE2EE.shared.renameMetadata(metadata, fileNameNew: fileNameNew, url: url, completion: completion)
            } else {
                NCNetworkingE2EE.shared.renameMetadata(metadataLive!, fileNameNew: fileNameNewLive, url: url) { (errorCode, errorDescription) in
                    if errorCode == 0 {
                        NCNetworkingE2EE.shared.renameMetadata(metadata, fileNameNew: fileNameNew, url: url, completion: completion)
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
        
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_no_permission_modify_file_", completion: completion)
            return
        }
        guard let fileNameNew = CCUtility.removeForbiddenCharactersServer(fileNameNew) else {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        if fileNameNew.count == 0 || fileNameNew == metadata.fileNameView {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        
        let fileNamePath = metadata.serverUrl + "/" + metadata.fileName
        let fileNameToPath = metadata.serverUrl + "/" + fileNameNew
                
        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false) { (account, errorCode, errorDescription) in
                    
            if errorCode == 0 {
                        
                NCManageDatabase.sharedInstance.renameMetadata(fileNameTo: fileNameNew, ocId: metadata.ocId)
                NCManageDatabase.sharedInstance.renameMedia(fileNameTo: fileNameNew, ocId: metadata.ocId)
                        
                if metadata.directory {
                            
                    let serverUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
                    let serverUrlTo = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: fileNameNew)!
                    if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                                
                        NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, serverUrlTo: serverUrlTo, etag: "", ocId: nil, fileId: nil, encrypted: directory.e2eEncrypted, richWorkspace: nil, account: metadata.account)
                    }
                            
                } else {
                            
                    NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: fileNameNew, etag: nil)
                    // Move file system
                    let atPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                    let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
                    do {
                        try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                    } catch { }
                    let atPathIcon = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileName)!
                    let toPathIcon = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: fileNameNew)!
                    do {
                        try FileManager.default.moveItem(atPath: atPathIcon, toPath: toPathIcon)
                    } catch { }
                }
                
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["ocId":metadata.ocId,"serverUrl":metadata.serverUrl])
            }
                    
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
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

    @objc func moveMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
    
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "serverUrlTo": serverUrlTo, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_no_permission_modify_file_", completion: completion)
            return
        }
        
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
        
        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite) { (account, errorCode, errorDescription) in
                    
            var metadataNew = tableMetadata()
            
            if errorCode == 0 {
    
                if metadata.directory {
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: account)
                }
                
                if let metadataMove = NCManageDatabase.sharedInstance.moveMetadata(ocId: metadata.ocId, serverUrlTo: serverUrlTo) {
                    metadataNew = metadataMove
                }
                NCManageDatabase.sharedInstance.moveMedia(ocId: metadata.ocId, serverUrlTo: serverUrlTo)
                                
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["serverUrl":metadata.serverUrl])
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["serverUrl":serverUrlTo])
            }
                    
            self.NotificationPost(name: k_notificationCenter_moveFile, userInfo: ["metadata": metadata, "metadataNew": metadataNew, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
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

    @objc func copyMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
    
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "serverUrlTo": serverUrlTo, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_no_permission_modify_file_", completion: completion)
            return
        }
        
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
        
        NCCommunication.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite) { (account, errorCode, errorDescription) in
                    
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_reloadDataSource), object: nil, userInfo: ["serverUrl":serverUrlTo])

            self.NotificationPost(name: k_notificationCenter_copyFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    //MARK: - Notification Post
    
    private func NotificationPost(name: String, userInfo: [AnyHashable : Any], errorDescription: Any?, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        var userInfo = userInfo
        DispatchQueue.main.async {
            
            if errorDescription == nil { userInfo["errorDescription"] = "" }
            else { userInfo["errorDescription"] = NSLocalizedString(errorDescription as! String, comment: "") }
            
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: name), object: nil, userInfo: userInfo)
            
            completion(userInfo["errorCode"] as! Int, userInfo["errorDescription"] as! String)
        }
    }
}
