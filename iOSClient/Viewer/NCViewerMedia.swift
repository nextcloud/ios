//
//  NCViewerMedia.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/09/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//

import Foundation
import KTVHTTPCache

class NCViewerMedia: NSObject {

    var detail: CCDetail!
    var metadata: tableMetadata!
    var videoURL: URL!
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var safeAreaBottom: Int = 0

    @objc static let sharedInstance: NCViewerMedia = {
        let viewMedia = NCViewerMedia()
        viewMedia.setupHTTPCache()
        return viewMedia
    }()

    @objc func viewMedia(_ metadata: tableMetadata, detail: CCDetail) {
        
        var videoURLProxy: URL!

        self.detail = detail
        self.metadata = metadata
        
        guard let rootView = UIApplication.shared.keyWindow else {
            return
        }
        
        if #available(iOS 11.0, *) {
            safeAreaBottom = Int(rootView.safeAreaInsets.bottom)
        }
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
        
            self.videoURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            videoURLProxy = videoURL
        
        } else {
            
            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return
            }
            
            self.videoURL = URL(string: stringURL)
            videoURLProxy = KTVHTTPCache.proxyURL(withOriginalURL: self.videoURL)
            
            guard let authData = (appDelegate.activeUser + ":" + appDelegate.activePassword).data(using: .utf8) else {
                return
            }
            
            let authValue = "Basic " + authData.base64EncodedString(options: [])
            KTVHTTPCache.downloadSetAdditionalHeaders(["Authorization":authValue, "User-Agent":CCUtility.getUserAgent()])
            
            // Disable Button Action (the file is in download via Proxy Server)
            detail.buttonAction.isEnabled = false
        }
        
        appDelegate.player = AVPlayer(url: videoURLProxy)
        appDelegate.playerController = AVPlayerViewController()
        
        appDelegate.playerController.player = appDelegate.player
        appDelegate.playerController.view.frame = CGRect(x: 0, y: 0, width: Int(rootView.bounds.size.width), height: Int(rootView.bounds.size.height) - Int(k_detail_Toolbar_Height) - safeAreaBottom - 1)
        appDelegate.playerController.allowsPictureInPicturePlayback = false
        detail.addChild(appDelegate.playerController)
        detail.view.addSubview(appDelegate.playerController.view)
        appDelegate.playerController.didMove(toParent: detail)
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) { (notification) in
            let player = notification.object as! AVPlayerItem
            player.seek(to: CMTime.zero)
        }
        
        appDelegate.player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        
        detail.isMediaObserver = true
        
        appDelegate.player.play()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath != nil && keyPath == "rate" {
            
            if appDelegate.player.rate == 1 {
                print("start")
            } else {
                print("stop")
            }
            
            // Save cache
            if !CCUtility.fileProviderStorageExists(self.metadata.ocId, fileNameView:self.metadata.fileNameView) {
                
                guard let url = KTVHTTPCache.cacheCompleteFileURL(with: self.videoURL) else {
                    return
                }
                
                CCUtility.copyFile(atPath: url.path, toPath: CCUtility.getDirectoryProviderStorageOcId(self.metadata.ocId, fileNameView: self.metadata.fileNameView))
                NCManageDatabase.sharedInstance.addLocalFile(metadata: self.metadata)
                KTVHTTPCache.cacheDelete(with: self.videoURL)
                
                // reload Data Source
                NCMainCommon.sharedInstance.reloadDatasource(ServerUrl:self.metadata.serverUrl, ocId: self.metadata.ocId, action: k_action_MOD)
                
                // Enabled Button Action (the file is in local)
                self.detail.buttonAction.isEnabled = true
            }
        }
    }
    
    @objc func removeObserver() {
        
        appDelegate.player.removeObserver(self, forKeyPath: "rate", context: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    @objc func setupHTTPCache() {
        
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
