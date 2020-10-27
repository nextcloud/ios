//
//  NCVideo.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation
import KTVHTTPCache

class NCVideoViewController: AVPlayerViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadata = tableMetadata()
    var videoURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHTTPCache()
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            
            videoURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            
        } else {
            
            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return
            }
            
            videoURL = KTVHTTPCache.proxyURL(withOriginalURL: URL(string: stringURL))
            
            guard let authData = (appDelegate.user + ":" + appDelegate.password).data(using: .utf8) else {
                return
            }
            
            let authValue = "Basic " + authData.base64EncodedString(options: [])
            KTVHTTPCache.downloadSetAdditionalHeaders(["Authorization":authValue, "User-Agent":CCUtility.getUserAgent()])
        }
        
        if let videoURL = videoURL {
            let video = AVPlayer(url: videoURL)
            player = video
        
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) { (notification) in
                let player = notification.object as! AVPlayerItem
                player.seek(to: CMTime.zero, completionHandler: nil)
            }
        
            player?.addObserver(self, forKeyPath: "rate", options: [], context: nil)
            player?.play()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        player?.pause()
        removeObserver()
        if KTVHTTPCache.proxyIsRunning() {
            KTVHTTPCache.proxyStop()
        }
    }
    
    //MARK: - Observer

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath != nil && keyPath == "rate" {
            
            if player?.rate == 1 {
                print("start")
            } else {
                print("stop")
            }
            
            // Save cache
            if !CCUtility.fileProviderStorageExists(self.metadata.ocId, fileNameView:self.metadata.fileNameView) {
                
                guard let videoURL = self.videoURL else { return }
                guard let url = KTVHTTPCache.cacheCompleteFileURL(with: videoURL) else { return }
                
                CCUtility.copyFile(atPath: url.path, toPath: CCUtility.getDirectoryProviderStorageOcId(self.metadata.ocId, fileNameView: self.metadata.fileNameView))
                NCManageDatabase.sharedInstance.addLocalFile(metadata: self.metadata)
                KTVHTTPCache.cacheDelete(with: self.videoURL)
                
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["ocId":self.metadata.ocId, "serverUrl":self.metadata.serverUrl])
            }
        }
    }
    
    @objc func removeObserver() {
        
        player?.removeObserver(self, forKeyPath: "rate", context: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    //MARK: - KTVHTTPCache
    
    @objc func setupHTTPCache() {
        
        if KTVHTTPCache.proxyIsRunning() {
            KTVHTTPCache.proxyStop()
        }
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
