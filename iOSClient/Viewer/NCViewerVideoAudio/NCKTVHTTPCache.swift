//
//  NCKTVHTTPCache.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation
import KTVHTTPCache

class NCKTVHTTPCache: NSObject {
    @objc static let shared: NCKTVHTTPCache = {
        let instance = NCKTVHTTPCache()
        instance.setupHTTPCache()
        return instance
    }()
    
    func setAuth(user: String, password: String) {
        
        guard let authData = (user + ":" + password).data(using: .utf8) else { return }
        
        let authValue = "Basic " + authData.base64EncodedString(options: [])
        KTVHTTPCache.downloadSetAdditionalHeaders(["Authorization":authValue, "User-Agent":CCUtility.getUserAgent()])
    }
    
    func getProxyURL(stringURL: String) -> URL {
        
        return KTVHTTPCache.proxyURL(withOriginalURL: URL(string: stringURL))
    }
    
    func getCompleteFileURL(videoURL: URL?) -> URL? {
        
        return KTVHTTPCache.cacheCompleteFileURL(with: videoURL)
    }
    
    func deleteCache(videoURL: URL?) {
        KTVHTTPCache.cacheDelete(with: videoURL)
    }
    
    func saveCache(metadata: tableMetadata) {
        
        if !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView:metadata.fileNameView) {
            
            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
            
            let videoURL = URL(string: stringURL)
            guard let url = KTVHTTPCache.cacheCompleteFileURL(with: videoURL) else { return }
            
            CCUtility.copyFile(atPath: url.path, toPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
            KTVHTTPCache.cacheDelete(with: videoURL)
            
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["ocId":metadata.ocId, "serverUrl":metadata.serverUrl])
        }
    }
    
    func stopProxy() {
        
        if KTVHTTPCache.proxyIsRunning() {
            KTVHTTPCache.proxyStop()
        }
    }
    
    func startProxy() {
        
        if !KTVHTTPCache.proxyIsRunning() {
            try? KTVHTTPCache.proxyStart()
        }
    }
    
    private func setupHTTPCache() {
        
        KTVHTTPCache.cacheSetMaxCacheLength(Int64(k_maxHTTPCache))
        
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            KTVHTTPCache.logSetConsoleLogEnable(true)
        }
        
        do {
            try KTVHTTPCache.proxyStart()
        } catch let error {
            print("Proxy Start error : \(error)")
        }
        
        KTVHTTPCache.encodeSetURLConverter { (url) -> URL? in
            print("URL Filter reviced URL : " + String(describing: url))
            return url
        }
        
        KTVHTTPCache.downloadSetUnacceptableContentTypeDisposer { (url, contentType) -> Bool in
            print("Unsupport Content-Type Filter reviced URL : " + String(describing: url) + " " + String(describing: contentType))
            return false
        }
    }
}
