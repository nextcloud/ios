// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    func buildDestination(metadata: tableMetadata, asset: PHAsset) -> URLRequest? {
        guard let url = metadata.serverUrlFileName.encodedToUrl as? URL else {
            logError("Invalid destination URL: \(metadata.serverUrlFileName)")
            return nil
        }

        guard let nkSession = nkComm.nksessions.session(forAccount: metadata.account) else {
            logError("Session not found for account: \(metadata.account)")
            return nil
        }

        let wifiOnly = metadata.session == nkComm.identifierSessionUploadBackgroundWWan
        let loginString = "\(nkSession.user):\(nkSession.password)"
        var request = URLRequest(url: url)

        guard let loginData = loginString.data(using: .utf8) else {
            logError("Unable to encode credentials for account: \(metadata.account)")
            return nil
        }

        request.httpMethod = "PUT"
        request.allowsCellularAccess = !wifiOnly
        request.allowsExpensiveNetworkAccess = true
        request.setValue(nkSession.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Basic \(loginData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "X-NC-WebDAV-Auto-Mkcol")

        if let creationDate = asset.creationDate,
           creationDate.timeIntervalSince1970 > 0 {
            request.setValue("\(creationDate.timeIntervalSince1970)", forHTTPHeaderField: "X-OC-CTime")
        }

        if let modificationDate = asset.modificationDate,
           modificationDate.timeIntervalSince1970 > 0 {
            request.setValue("\(modificationDate.timeIntervalSince1970)", forHTTPHeaderField: "X-OC-MTime")
        }

        logDebug("Destination created for \(metadata.fileName) -> \(metadata.serverUrlFileName)")

        return request
    }
}
