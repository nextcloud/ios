//
//  NCNetworking.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 23/10/19.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

@objc public protocol NCNetworkingDelegate {
    @objc optional func downloadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, description: String?, error: Error?, statusCode: Int)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, error: Error?, statusCode: Int)
}

@objc class NCNetworking: NSObject, NCCommunicationCommonDelegate {
    @objc public static let sharedInstance: NCNetworking = {
        let instance = NCNetworking()
        return instance
    }()
    
    var account = ""
    
    // Protocol
    var delegate: NCNetworkingDelegate?
    
    //MARK: - Setup
    
    @objc public func setup(account: String, delegate: NCNetworkingDelegate?) {
        self.account = account
        self.delegate = delegate
    }
    
    //MARK: - Communication Delegate
       
    func authenticationChallenge(_ challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if NCNetworking.sharedInstance.checkTrustedChallenge(challenge: challenge, directoryCertificate: CCUtility.getDirectoryCerificates()) {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential.init(trust: challenge.protectionSpace.serverTrust!))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }
    
    func downloadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.downloadProgress?(progress, fileName: fileName, ServerUrl: ServerUrl, session: session, task: task)
    }
    
    func uploadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.uploadProgress?(progress, fileName: fileName, ServerUrl: ServerUrl, session: session, task: task)
    }
    
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, error: Error?, statusCode: Int) {
        delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size:size, description: description, error: error, statusCode: statusCode)
    }
    
    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, description: String?, error: Error?, statusCode: Int) {
        delegate?.downloadComplete?(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, description: description, error: error, statusCode: statusCode)
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
    
    @objc func convertFiles(_ files: [NCFile], urlString: String, serverUrl : String?, user: String, metadataFolder: UnsafeMutablePointer<tableMetadata>) -> [tableMetadata] {
        
        var metadatas = [tableMetadata]()
        
        for file in files {
            
            if !CCUtility.getShowHiddenFiles() && file.fileName.first == "." { continue }
            
            let metadata = tableMetadata()
            
            metadata.account = account
            metadata.commentsUnread = file.commentsUnread
            metadata.contentType = file.contentType
            metadata.creationDate = file.creationDate
            metadata.date = file.date
            metadata.directory = file.directory
            metadata.e2eEncrypted = file.e2eEncrypted
            metadata.etag = file.etag
            metadata.favorite = file.favorite
            metadata.fileId = file.fileId
            metadata.fileName = file.fileName
            metadata.fileNameView = file.fileName
            metadata.hasPreview = file.hasPreview
            metadata.mountType = file.mountType
            metadata.ocId = file.ocId
            metadata.ownerId = file.ownerId
            metadata.ownerDisplayName = file.ownerDisplayName
            metadata.permissions = file.permissions
            metadata.quotaUsedBytes = file.quotaUsedBytes
            metadata.quotaAvailableBytes = file.quotaAvailableBytes
            metadata.richWorkspace = file.richWorkspace
            metadata.resourceType = file.resourceType
            if serverUrl == nil {
                metadata.serverUrl = urlString + file.path.replacingOccurrences(of: "/remote.php/dav/files/"+user, with: "").dropLast()
            } else {
                metadata.serverUrl = serverUrl!
            }
            metadata.size = file.size
                        
            CCUtility.insertTypeFileIconName(file.fileName, metadata: metadata)
            
            // Folder
            if file.fileName.count == 0 {
                metadataFolder.initialize(to: metadata)
            } else {
                metadatas.append(metadata)
            }
        }
        
        return metadatas
    }
}
