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

    static func openOnlyOffice(metadata: tableMetadata?) -> Bool {
        var type = ""
        if self.isDoc(mimeType: metadata?.contentType) {
            type = "text"
        } else if self.isSpreadsheet(mimeType: metadata?.contentType) {
            type = "spreadsheet"
        } else if self.isPresentation(mimeType: metadata?.contentType) {
            type = "presentation"
        } else {
            return false
        }

        let driveID = InfomaniakUtils.getServerId(url: metadata?.serverUrl ?? "")

        let stringFileId = metadata?.fileId
        let regexFileID = try? NSRegularExpression(pattern: "^0*", options: .caseInsensitive)
        let fileID = regexFileID?.stringByReplacingMatches(in: stringFileId ?? "", options: [], range: NSRange(location: 0, length: stringFileId?.count ?? 0), withTemplate: "")

        let url = "https://drive.infomaniak.com/app/drive/\(driveID)/preview/\(type)/\(fileID ?? "")"

        if let url = URL(string: url) {
            UIApplication.shared.open(url)
        }

        return true
    }

    static func isDocumentModifiableWithOnlyOffice(mimeType: String?) -> Bool {
        self.isDoc(mimeType: mimeType) || self.isSpreadsheet(mimeType: mimeType) || self.isPresentation(mimeType: mimeType)
    }

    static func isDoc(mimeType: String?) -> Bool {
        mimeType?.hasPrefix("application/msword") ?? false
                || mimeType?.hasPrefix("application/vnd.ms-word") ?? false
                || mimeType?.hasPrefix("application/vnd.oasis.opendocument.text") ?? false
                || mimeType?.hasPrefix("application/vnd.openxmlformats-officedocument.wordprocessingml") ?? false
    }

    static func isSpreadsheet(mimeType: String?) -> Bool {
        mimeType?.hasPrefix("application/vnd.ms-excel") ?? false
                || mimeType?.hasPrefix("application/msexcel") ?? false
                || mimeType?.hasPrefix("application/x-msexcel") ?? false
                || mimeType?.hasPrefix("application/vnd.openxmlformats-officedocument.spreadsheetml") ?? false
                || mimeType?.hasPrefix("application/vnd.oasis.opendocument.spreadsheet") ?? false
    }

    static func isPresentation(mimeType: String?) -> Bool {
        mimeType?.hasPrefix("application/powerpoint") ?? false
                || mimeType?.hasPrefix("application/mspowerpoint") ?? false
                || mimeType?.hasPrefix("application/vnd.ms-powerpoint") ?? false
                || mimeType?.hasPrefix("application/x-mspowerpoint") ?? false
                || mimeType?.hasPrefix("application/vnd.openxmlformats-officedocument.presentationml") ?? false
                || mimeType?.hasPrefix("application/vnd.oasis.opendocument.presentation") ?? false
    }


}
