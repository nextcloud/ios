//
//  NCCommunication.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/10/2019.
//  Copyright © 2019 TWS. All rights reserved.
//

import Foundation
import Alamofire

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
    
    @objc func readFolder(path: String, user: String, password: String) {
        
        // URL
        var url: URLConvertible
        do {
            try url = path.asURL()
        } catch _ {
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
                print("Board creation failed with error: \(error.localizedDescription)")
            case .success( _):
                if let data = response.data {
                    print("JSON: \(data)")
                }
                print("success")
            }
        }
    }
}
