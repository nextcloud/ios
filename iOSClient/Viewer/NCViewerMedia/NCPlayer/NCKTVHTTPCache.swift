//
//  NCKTVHTTPCache.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

import UIKit
import KTVHTTPCache

class NCKTVHTTPCache: NSObject {
    @objc static let shared: NCKTVHTTPCache = {
        let instance = NCKTVHTTPCache()
        instance.setupHTTPCache()
        return instance
    }()

    func getVideoURL(metadata: tableMetadata) -> (url: URL?, isProxy: Bool) {

        if CCUtility.fileProviderStorageExists(metadata) || metadata.isDirectoryE2EE {

            return (URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)), false)

        } else {

            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return (nil, false) }

            return (NCKTVHTTPCache.shared.getProxyURL(stringURL: stringURL), true)
        }
    }

    func restartProxy(user: String, password: String) {

        if KTVHTTPCache.proxyIsRunning() {
            KTVHTTPCache.proxyStop()
        }

        startProxy(user: user, password: password)
    }

    private func startProxy(user: String, password: String) {

        guard let authData = (user + ":" + password).data(using: .utf8) else { return }

        let authValue = "Basic " + authData.base64EncodedString(options: [])
        KTVHTTPCache.downloadSetAdditionalHeaders(["Authorization": authValue, "User-Agent": CCUtility.getUserAgent()])

        if !KTVHTTPCache.proxyIsRunning() {
            do {
                try KTVHTTPCache.proxyStart()
            } catch let error {
                print("Proxy Start error : \(error)")
            }
        }
    }

    private func stopProxy() {

        if KTVHTTPCache.proxyIsRunning() {
            KTVHTTPCache.proxyStop()
        }
    }

    func getProxyURL(stringURL: String) -> URL {

        return KTVHTTPCache.proxyURL(withOriginalURL: URL(string: stringURL))
    }

    func getCacheCompleteFileURL(videoURL: URL?) -> URL? {

        return KTVHTTPCache.cacheCompleteFileURL(with: videoURL)
    }

    func deleteCache(videoURL: URL?) {

        KTVHTTPCache.cacheDelete(with: videoURL)
    }

    @objc func deleteAllCache() {

        KTVHTTPCache.cacheDeleteAllCaches()
    }

    func saveCache(metadata: tableMetadata) {

        if !CCUtility.fileProviderStorageExists(metadata) {

            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }

            let videoURL = URL(string: stringURL)
            guard let url = KTVHTTPCache.cacheCompleteFileURL(with: videoURL) else { return }

            CCUtility.copyFile(atPath: url.path, toPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            NCManageDatabase.shared.addLocalFile(metadata: metadata)
            KTVHTTPCache.cacheDelete(with: videoURL)

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": metadata.serverUrl])
        }
    }

    func getDownloadStatusCode(metadata: tableMetadata) -> Int {

        guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return 0 }
        let url = URL(string: stringURL)
        return KTVHTTPCache.downloadStatusCode(url)
    }

    private func setupHTTPCache() {

        KTVHTTPCache.cacheSetMaxCacheLength(NCGlobal.shared.maxHTTPCache)

        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            KTVHTTPCache.logSetConsoleLogEnable(true)
        }

        do {
            try KTVHTTPCache.proxyStart()
        } catch let error {
            print("Proxy Start error : \(error)")
        }

        KTVHTTPCache.encodeSetURLConverter { url -> URL? in
            print("URL Filter received URL : " + String(describing: url))
            return url
        }

        KTVHTTPCache.downloadSetUnacceptableContentTypeDisposer { url, contentType -> Bool in
            print("Unsupport Content-Type Filter received URL : " + String(describing: url) + " " + String(describing: contentType))
            return false
        }
    }
}
