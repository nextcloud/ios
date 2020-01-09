//
//  InfomaniakUtils.swift
//  kDrive
//
//  Created by Philippe Weidmann on 24.12.19.
//  Copyright © 2019 TWS. All rights reserved.
//

import Foundation

@objcMembers
class InfomaniakUtils: NSObject {

    static func downloadProfilePictureWith(account: tableAccount, url: String, completion: @escaping (_ data: Data?, _ message: String?, _ errorCode: Int) -> Void) {
        var request: URLRequest!
        if let url = URL(string: url), let policy = NSURLRequest.CachePolicy(rawValue: 0) {
            request = URLRequest(url: url, cachePolicy: policy, timeoutInterval: 20.0)
        }

        if let basicAuthCredentials = UtilsFramework.afBase64EncodedString(from: "\(account.user):\(account.password)") {
            request?.addValue(CCUtility.getUserAgent(), forHTTPHeaderField: "User-Agent")
            request?.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
            request?.addValue("Basic " + basicAuthCredentials, forHTTPHeaderField: "Authorization")
        }

        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) in
            if (error != nil) {
                var message = ""
                var errorCode = 0

                if let httpResponse = (response as? HTTPURLResponse) {
                    errorCode = httpResponse.statusCode
                }

                if (errorCode == 0 || (errorCode >= 200 && errorCode < 300)) {
                    errorCode = (error! as NSError).code
                }

                if (errorCode == 503) {
                    message = NSLocalizedString("_server_error_retry_", comment: "");
                } else {
                    message = error!.localizedDescription
                }

                completion(data, message, errorCode)
            } else {
                completion(data, nil, 0)
            }
        }

        task.resume()
    }

    static func getServerId(url: String) -> String {
        var driveID = ""
        let pattern = ".+?(\\d+)\\.connect\\.drive\\.infomaniak\\.com.*"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)

        if let match = regex?.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.utf16.count)) {
            if let driveIDRange = Range(match.range(at: 1), in: url) {
                driveID = String(url[driveIDRange])
            }
        }

        return driveID
    }

}
