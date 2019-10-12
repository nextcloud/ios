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
    
    let NCResource =
    """
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
    """
    
    @objc func readFolder(path: String, user: String, password: String, completionHandler: @escaping (_ result: [NCFile]?, _ error: Error?) -> Void) {
        
        // URL
        var url: URLConvertible
        do {
            try url = path.asURL()
        } catch _ {
            completionHandler(nil, nil)
            return
        }
        
        // Headers
        var headers: HTTPHeaders = [.authorization(username: user, password: password)]
        headers.update(.userAgent(CCUtility.getUserAgent()))
        headers.update(.contentType("application/xml"))
        headers.update(name: "Depth", value: "1")

        // Parameters
        //let parameters: Parameters = ["":"<?xml version=\"1.0\" encoding=\"UTF-8\"?><d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\"><d:prop>" + NCResource + "</d:prop></d:propfind>"]
        
        // Method
        let method = HTTPMethod(rawValue: "PROPFIND")
        
        AF.request(url, method: method, parameters:[:], encoding: URLEncoding.httpBody, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData { (response) in
            switch response.result {
            case.failure(let error):
                completionHandler(nil, error)
            case .success( _):
                var files = [NCFile]()
                if let data = response.data {
                    
                    let xml = XML.parse(data)
                    let elements = xml["d:multistatus", "d:response"]
                    for element in elements {
                        let file = NCFile()
                        if let href = element["d:href"].text { file.path = href }
                        files.append(file)
                    }
                }
                completionHandler(files, nil)
            }
        }
    }
}
