//
//  NCCommunication.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/10/19.
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
import Alamofire
import SwiftyXMLParser

class NCCommunication: SessionDelegate {
    @objc static let sharedInstance: NCCommunication = {
        let instance = NCCommunication()
        return instance
    }()
    
    var username = ""
    var password = ""
    var userAgent: String?
    
    //MARK: - Settings

    @objc func settingAccount(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
    @objc func settingUserAgent(_ userAgent: String) {
        self.userAgent = userAgent
    }
    
    //MARK: - webDAV

    @objc func createFolder(serverUrl: String, fileName: String, completionHandler: @escaping (_ ocId: String?, _ date: NSDate?, _ error: Error?) -> Void) {
        
        // url
        var serverUrl = serverUrl
        var url: URLConvertible
        do {
            if serverUrl.last == "/" {
                serverUrl = serverUrl + fileName
            } else {
                serverUrl = serverUrl + "/" + fileName
            }
            try url = serverUrl.asURL()
        } catch let error {
            completionHandler(nil, nil, error)
            return
        }
        
        // method
        let method = HTTPMethod(rawValue: "MKCOL")
        
        // headers
        var headers: HTTPHeaders = [.authorization(username: self.username, password: self.password)]
        if let userAgent = self.userAgent { headers.update(.userAgent(userAgent)) }
        
        AF.request(url, method: method, parameters:nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response { (response) in
            switch response.result {
            case.failure(let error):
                completionHandler(nil, nil, error)
            case .success( _):
                let ocId = response.response?.allHeaderFields["OC-FileId"] as! String?
                if let dateString = response.response?.allHeaderFields["Date"] as! String? {
                    if let date = NCCommunicationCommon.sharedInstance.convertDate(dateString, format: "EEE, dd MMM y HH:mm:ss zzz") {
                        completionHandler(ocId, date, nil)
                    } else { completionHandler(nil, nil, NSError(domain: NSCocoaErrorDomain, code: NSURLErrorBadServerResponse, userInfo: nil)) }
                } else { completionHandler(nil, nil, NSError(domain: NSCocoaErrorDomain, code: NSURLErrorBadServerResponse, userInfo: nil)) }
            }
        }
    }
    
    @objc func deleteFileOrFolder(serverUrl: String, fileName: String, completionHandler: @escaping (_ error: Error?) -> Void) {
        
        // url
        var serverUrl = serverUrl
        var url: URLConvertible
        do {
            if serverUrl.last == "/" {
                serverUrl = serverUrl + fileName
            } else {
                serverUrl = serverUrl + "/" + fileName
            }
            try url = serverUrl.asURL()
        } catch let error {
            completionHandler(error)
            return
        }
        
        // method
        let method = HTTPMethod(rawValue: "DELETE")
        
        // headers
        var headers: HTTPHeaders = [.authorization(username: self.username, password: self.password)]
        if let userAgent = self.userAgent { headers.update(.userAgent(userAgent)) }
        
        AF.request(url, method: method, parameters:nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response { (response) in
            switch response.result {
            case.failure(let error):
                completionHandler(error)
            case .success( _):
                completionHandler(nil)
            }
        }
    }
    
    @objc func moveFileOrFolder(fileNamePath: String, fileNamePathDestination: String,completionHandler: @escaping (_ error: Error?) -> Void) {
        
        // url
        var url: URLConvertible
        do {
            try url = fileNamePath.asURL()
        } catch let error {
            completionHandler(error)
            return
        }
        
        // method
        let method = HTTPMethod(rawValue: "MOVE")
        
        // headers
        var headers: HTTPHeaders = [.authorization(username: self.username, password: self.password)]
        if let userAgent = self.userAgent { headers.update(.userAgent(userAgent)) }
        headers.update(name: "Destination", value: fileNamePathDestination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        headers.update(name: "Overwrite", value: "T")
        
        AF.request(url, method: method, parameters:nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response { (response) in
            switch response.result {
            case.failure(let error):
                completionHandler(error)
            case .success( _):
                completionHandler(nil)
            }
        }
    }
    
    @objc func readFileOrFolder(serverUrl: String, depth: String, completionHandler: @escaping (_ result: [NCFile], _ error: Error?) -> Void) {
        
        var files = [NCFile]()
        var isNotFirstFileOfList: Bool = false
        let dataFile =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:prop>"

        <d:getlastmodified />
        <d:getetag />
        <d:getcontenttype />
        <d:resourcetype />
        <d:quota-available-bytes />
        <d:quota-used-bytes />

        <permissions xmlns=\"http://owncloud.org/ns\"/>
        <id xmlns=\"http://owncloud.org/ns\"/>
        <fileid xmlns=\"http://owncloud.org/ns\"/>
        <size xmlns=\"http://owncloud.org/ns\"/>
        <favorite xmlns=\"http://owncloud.org/ns\"/>
        <share-types xmlns=\"http://owncloud.org/ns\"/>
        <owner-id xmlns=\"http://owncloud.org/ns\"/>
        <owner-display-name xmlns=\"http://owncloud.org/ns\"/>
        <comments-unread xmlns=\"http://owncloud.org/ns\"/>

        <is-encrypted xmlns=\"http://nextcloud.org/ns\"/>
        <has-preview xmlns=\"http://nextcloud.org/ns\"/>
        <mount-type xmlns=\"http://nextcloud.org/ns\"/>

        </d:prop>
        </d:propfind>
        """

        // url
        var serverUrl = String(serverUrl)
        if depth == "1" && serverUrl.last != "/" { serverUrl = serverUrl + "/" }
        if depth == "0" && serverUrl.last == "/" { serverUrl = String(serverUrl.removeLast()) }
        guard let url = NCCommunicationCommon.sharedInstance.encodeUrlString(serverUrl) else {
            completionHandler(files, NSError(domain: NSCocoaErrorDomain, code: NSURLErrorUnsupportedURL, userInfo: nil))
            return
        }
        
        // method
        let method = HTTPMethod(rawValue: "PROPFIND")
        
        // headers
        var headers: HTTPHeaders = [.authorization(username: self.username, password: self.password)]
        if let userAgent = self.userAgent { headers.update(.userAgent(userAgent)) }
        headers.update(.contentType("application/xml"))
        headers.update(name: "Depth", value: depth)

        // request
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = dataFile.data(using: .utf8)
        } catch let error {
            completionHandler(files, error)
            return
        }
        
        AF.request(urlRequest).validate(statusCode: 200..<300).responseData { (response) in
            switch response.result {
            case.failure(let error):
                completionHandler(files, error)
            case .success( _):
                if let data = response.data {
                    let xml = XML.parse(data)
                    let elements = xml["d:multistatus", "d:response"]
                    for element in elements {
                        let file = NCFile()
                        if let href = element["d:href"].text {
                            var fileNamePath = href
                            // directory
                            if href.last == "/" {
                                fileNamePath = String(href[..<href.index(before: href.endIndex)])
                                file.directory = true
                            }
                            // path
                            file.path = (fileNamePath as NSString).deletingLastPathComponent + "/"
                            file.path = file.path.removingPercentEncoding ?? ""
                            // fileName
                            if isNotFirstFileOfList {
                                file.fileName = (fileNamePath as NSString).lastPathComponent
                                file.fileName = file.fileName.removingPercentEncoding ?? ""
                            } else {
                                file.fileName = ""
                            }
                        }
                        let propstat = element["d:propstat"][0]
                        
                        // d:
                        
                        if let getlastmodified = propstat["d:prop", "d:getlastmodified"].text {
                            if let date = NCCommunicationCommon.sharedInstance.convertDate(getlastmodified, format: "EEE, dd MMM y HH:mm:ss zzz") {
                                file.date = date
                            }
                        }
                        if let getetag = propstat["d:prop", "d:getetag"].text {
                            file.etag = getetag.replacingOccurrences(of: "\"", with: "")
                        }
                        if let getcontenttype = propstat["d:prop", "d:getcontenttype"].text {
                            file.contentType = getcontenttype
                        }
                        if let resourcetype = propstat["d:prop", "d:resourcetype"].text {
                            file.resourceType = resourcetype
                        }
                        if let quotaavailablebytes = propstat["d:prop", "d:quota-available-bytes"].text {
                            file.quotaAvailableBytes = Double(quotaavailablebytes) ?? 0
                        }
                        if let quotausedbytes = propstat["d:prop", "d:quota-used-bytes"].text {
                            file.quotaUsedBytes = Double(quotausedbytes) ?? 0
                        }
                        
                        // oc:
                       
                        if let permissions = propstat["d:prop", "oc:permissions"].text {
                            file.permissions = permissions
                        }
                        if let ocId = propstat["d:prop", "oc:id"].text {
                            file.ocId = ocId
                        }
                        if let fileId = propstat["d:prop", "oc:fileid"].text {
                            file.fileId = fileId
                        }
                        if let size = propstat["d:prop", "oc:size"].text {
                            file.size = Double(size) ?? 0
                        }
                        if let favorite = propstat["d:prop", "oc:favorite"].text {
                            file.favorite = (favorite as NSString).boolValue
                        }
                        if let ownerid = propstat["d:prop", "oc:owner-id"].text {
                            file.ownerId = ownerid
                        }
                        if let ownerdisplayname = propstat["d:prop", "oc:owner-display-name"].text {
                            file.ownerDisplayName = ownerdisplayname
                        }
                        if let commentsunread = propstat["d:prop", "oc:comments-unread"].text {
                            file.commentsUnread = (commentsunread as NSString).boolValue
                        }
                        
                        // nc:
                        if let encrypted = propstat["d:prop", "nc:encrypted"].text {
                            file.e2eEncrypted = (encrypted as NSString).boolValue
                        }
                        if let haspreview = propstat["d:prop", "nc:has-preview"].text {
                            file.hasPreview = (haspreview as NSString).boolValue
                        }
                        if let mounttype = propstat["d:prop", "nc:mount-type"].text {
                            file.mountType = mounttype
                        }
                        
                        isNotFirstFileOfList = true;
                        files.append(file)
                    }
                    completionHandler(files, nil)
                } else {
                    completionHandler(files, NSError(domain: NSCocoaErrorDomain, code: NSURLErrorBadServerResponse, userInfo: nil))
                }
            }
        }
    }
    
    //MARK: - API
    @objc func downloadPreview(serverUrl: String, fileNamePathSource: String, fileNamePathLocalDestination: String, width: CGFloat, height: CGFloat, completionHandler: @escaping (_ data: Data?, _ error: Error?) -> Void) {
        
        // url
        var serverUrl = String(serverUrl)
        if serverUrl.last != "/" { serverUrl = serverUrl + "/" }
        serverUrl = serverUrl + "index.php/core/preview.png?file=" + fileNamePathSource + "&x=\(width)&y=\(height)&a=1&mode=cover"
        guard let url = NCCommunicationCommon.sharedInstance.encodeUrlString(serverUrl) else {
            completionHandler(nil, NSError(domain: NSCocoaErrorDomain, code: NSURLErrorUnsupportedURL, userInfo: nil))
            return
        }
        
        // method
        let method = HTTPMethod(rawValue: "GET")
        
        // headers
        var headers: HTTPHeaders = [.authorization(username: self.username, password: self.password)]
        if let userAgent = self.userAgent { headers.update(.userAgent(userAgent)) }

        AF.request(url, method: method, parameters:nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response { (response) in
            switch response.result {
            case.failure(let error):
                completionHandler(nil, error)
            case .success( _):
                if let data = response.data {
                    do {
                        let url = URL.init(fileURLWithPath: fileNamePathLocalDestination)
                        try  data.write(to: url, options: .atomic)
                        completionHandler(data, nil)
                    } catch let error {
                        completionHandler(nil, error)
                    }
                } else {
                    completionHandler(nil, NSError(domain: NSCocoaErrorDomain, code: NSURLErrorCannotDecodeContentData, userInfo: nil))
                }
            }
        }
    }
    
    
    //MARK: - Download
    
    @objc func download(serverUrl: String, fileName: String, fileNamePathDestination: String, completionHandler: @escaping (_ error: Error?) -> Void) {
        
        // url
        var serverUrl = serverUrl
        var url: URLConvertible
        do {
            if serverUrl.last == "/" {
                serverUrl = serverUrl + fileName
            } else {
                serverUrl = serverUrl + "/" + fileName
            }
            try url = serverUrl.asURL()
        } catch let error {
            completionHandler(error)
            return
        }
        
        // destination
        var destination: Alamofire.DownloadRequest.Destination?
        if let fileNamePathDestinationURL = URL(string: fileNamePathDestination) {
            let destinationFile: DownloadRequest.Destination = { _, _ in
                return (fileNamePathDestinationURL, [.removePreviousFile, .createIntermediateDirectories])
            }
            destination = destinationFile
        }
        
        // headers
        var headers: HTTPHeaders = [.authorization(username: self.username, password: self.password)]
        if let userAgent = self.userAgent { headers.update(.userAgent(userAgent)) }
        
        AF.download(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil, to: destination).downloadProgress { progress in
            //self.postProgress(progress: progress)
        }.responseData { response in
            switch response.result {
            case.failure(let error):
                completionHandler(error)
            case .success( _):
                completionHandler(nil)
            }
        }
    }
    
    //MARK: - SessionDelegate

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if CCCertificate.sharedManager().checkTrustedChallenge(challenge) {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling,             URLCredential.init(trust: challenge.protectionSpace.serverTrust!))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
        
    }
}

