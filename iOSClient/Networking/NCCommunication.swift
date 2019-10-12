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

class NCCommunication: NSObject {
    @objc static let sharedInstance: NCCommunication = {
        let instance = NCCommunication()
        return instance
    }()
    
    //MARK: - webDAV

    @objc func readFolder(serverUrl: String, account: String, user: String, password: String, depth: String, userAgent: String, completionHandler: @escaping (_ result: [NCFile], _ account: String,_ error: Error?) -> Void) {
        
        var files = [NCFile]()
        let dataFile =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:prop>"
        <d:displayname/>
        <d:getcontenttype/>
        <d:resourcetype/>
        <d:getcontentlength/>
        <d:getlastmodified/>
        <d:creationdate/>
        <d:getetag/>
        <d:quota-used-bytes/>
        <d:quota-available-bytes/>
        <permissions xmlns=\"http://owncloud.org/ns\"/>
        <id xmlns=\"http://owncloud.org/ns\"/>
        <fileid xmlns=\"http://owncloud.org/ns\"/>
        <size xmlns=\"http://owncloud.org/ns\"/>
        <favorite xmlns=\"http://owncloud.org/ns\"/>
        <is-encrypted xmlns=\"http://nextcloud.org/ns\"/>
        <mount-type xmlns=\"http://nextcloud.org/ns\"/>
        <owner-id xmlns=\"http://owncloud.org/ns\"/>
        <owner-display-name xmlns=\"http://owncloud.org/ns\"/>
        <comments-unread xmlns=\"http://owncloud.org/ns\"/>
        <has-preview xmlns=\"http://nextcloud.org/ns\"/>
        <trashbin-filename xmlns=\"http://nextcloud.org/ns\"/>
        <trashbin-original-location xmlns=\"http://nextcloud.org/ns\"/>
        <trashbin-deletion-time xmlns=\"http://nextcloud.org/ns\"/>"
        </d:prop>
        </d:propfind>
        """

        // url
        var url: URLConvertible
        do {
            try url = serverUrl.asURL()
        } catch let error {
            completionHandler(files, account, error)
            return
        }
        
        // Headers
        var headers: HTTPHeaders = [.authorization(username: user, password: password)]
        headers.update(.userAgent(userAgent))
        headers.update(.contentType("application/xml"))
        headers.update(name: "Depth", value: depth)

        // Parameters
        //let parameters: Parameters = ["":"<?xml version=\"1.0\" encoding=\"UTF-8\"?><d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\"><d:prop>" + NCResourceList + "</d:prop></d:propfind>"]
        
        // Method
        let method = HTTPMethod(rawValue: "PROPFIND")
        
        AF.request(url, method: method, parameters:[:], encoding: URLEncoding.httpBody, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData { (response) in
            switch response.result {
            case.failure(let error):
                completionHandler(files, account, error)
            case .success( _):
                if let data = response.data {
                    let xml = XML.parse(data)
                    let elements = xml["d:multistatus", "d:response"]
                    for element in elements {
                        let file = NCFile()
                        if let href = element["d:href"].text {
                            file.path = href.removingPercentEncoding ?? ""
                        }
                        let propstat = element["d:propstat"][0]
                        
                        if let getetag = propstat["d:prop", "d:getetag"].text {
                            file.etag = getetag.replacingOccurrences(of: "\"", with: "")
                        }
                        if let getlastmodified = propstat["d:prop", "d:getlastmodified"].text {
                            if let date = NCCommunicationCommon.sharedInstance.convertDate(getlastmodified, format: "EEE, dd MMM y HH:mm:ss zzz") {
                                file.date = date
                            }
                        }
                        if let quotaavailablebytes = propstat["d:prop", "d:quota-available-bytes"].text {
                            file.quotaAvailableBytes = Double(quotaavailablebytes) ?? 0
                        }
                        if let quotausedbytes = propstat["d:prop", "d:quota-used-bytes"].text {
                            file.quotaUsedBytes = Double(quotausedbytes) ?? 0
                        }
                        
                        files.append(file)
                    }
                }
                completionHandler(files, account, nil)
            }
        }
    }
    
    //MARK: - Download
    
    @objc func download(serverUrl: String, fileName: String, fileNamePathDestination: String, account: String, user: String, password: String, userAgent: String, completionHandler: @escaping (_ account: String,_ error: Error?) -> Void) {
        
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
            completionHandler(account, error)
            return
        }
        
        // Destination
        var destination: Alamofire.DownloadRequest.Destination?
        if let fileNamePathDestinationURL = URL(string: fileNamePathDestination) {
            let destinationFile: DownloadRequest.Destination = { _, _ in
                return (fileNamePathDestinationURL, [.removePreviousFile, .createIntermediateDirectories])
            }
            destination = destinationFile
        }
        
        // Headers
        var headers: HTTPHeaders = [.authorization(username: user, password: password)]
        headers.update(.userAgent(userAgent))
        
        AF.download(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil, to: destination).downloadProgress { progress in
            //self.postProgress(progress: progress)
        }.responseData { response in
            switch response.result {
            case.failure(let error):
                completionHandler(account, error)
            case .success( _):
                completionHandler(account, nil)
            }
        }
    }

}

