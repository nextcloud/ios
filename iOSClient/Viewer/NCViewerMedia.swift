//
//  NCViewerMedia.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/09/18.
//  Copyright © 2018 TWS. All rights reserved.
//

import Foundation
import KTVHTTPCache

class NCViewerMedia: NSObject {
    
    @objc static let sharedInstance: NCViewerMedia = {
        let instance = NCViewerMedia()
        return instance
    }()

    var viewDetail: CCDetail!
    var metadata: tableMetadata!
    var videoURL: URL!
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc func viewMedia(_ metadata: tableMetadata, viewDetail: CCDetail, width: Int, height: Int) {
        
        var videoURLProxy: URL!

        self.viewDetail = viewDetail
        self.metadata = metadata
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            return
        }
        
        if CCUtility.fileProviderStorageExists(metadata.fileID, fileNameView: metadata.fileNameView) {
        
            self.videoURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageFileID(metadata.fileID, fileNameView: metadata.fileNameView))
            videoURLProxy = videoURL
        
        } else {
            
            guard let stringURL = (serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return
            }
            
            self.videoURL = URL(string: stringURL)
            videoURLProxy = KTVHTTPCache.proxyURL(withOriginalURL: self.videoURL)
            
            guard let authData = (appDelegate.activeUser + ":" + appDelegate.activePassword).data(using: .utf8) else {
                return
            }
            
            let authValue = "Basic " + authData.base64EncodedString(options: [])
            let header = [authValue:"Authorization", CCUtility.getUserAgent():"User-Agent"] as [String : String]
            KTVHTTPCache.downloadSetAdditionalHeaders(header)
            
            // Disable Button Action (the file is in download via Proxy Server)
            viewDetail.buttonAction.isEnabled = false
        }
        
        appDelegate.player = AVPlayer(url: videoURLProxy)
        appDelegate.playerController = AVPlayerViewController()
        
        appDelegate.playerController.player = appDelegate.player
        appDelegate.playerController.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        appDelegate.playerController.allowsPictureInPicturePlayback = false
        viewDetail.addChild(appDelegate.playerController)
        viewDetail.view.addSubview(appDelegate.playerController.view)
        appDelegate.playerController.didMove(toParent: viewDetail)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.itemDidFinishPlaying(notification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        appDelegate.player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        
        viewDetail.isMediaObserver = true
        
        appDelegate.player.play()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "rate" {
            
            if appDelegate.player?.rate != nil {
                print("start")
            } else {
                print("stop")
            }
            
            saveCacheToFileProvider()
        }
    }
    
    @objc func removeObserverAVPlayerItemDidPlayToEndTime () {
        
         NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    @objc func itemDidFinishPlaying(notification: NSNotification) {
        
        let player = notification.object as! AVPlayerItem
        player.seek(to: CMTime.zero)
    }
    
    func saveCacheToFileProvider() {
        
        if !CCUtility.fileProviderStorageExists(self.metadata.fileID, fileNameView:self.metadata.fileNameView) {
            guard let url = KTVHTTPCache.cacheCompleteFileURLIfExisted(with: self.videoURL) else {
                return
            }
            
            CCUtility.copyFile(atPath: url.path, toPath: CCUtility.getDirectoryProviderStorageFileID(self.metadata.fileID, fileNameView: self.metadata.fileNameView))
            NCManageDatabase.sharedInstance.addLocalFile(metadata: self.metadata)
            KTVHTTPCache.cacheDelete(with: self.videoURL)
            
            // reload Data Source
            NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: NCManageDatabase.sharedInstance.getServerUrl(self.metadata.directoryID), fileID: self.metadata.fileID, action: k_action_MOD)
            
            // Enabled Button Action (the file is in local)
            self.viewDetail.buttonAction.isEnabled = true
        }
    }
    
    @objc func setupHTTPCache() {
        
        var error: NSError?

        KTVHTTPCache.cacheSetMaxCacheLength(Int64(k_maxHTTPCache))
        
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            KTVHTTPCache.logSetConsoleLogEnable(true)
        }
        
        KTVHTTPCache.proxyStart(&error)
        if error == nil {
            print("Proxy Start Success")
        } else {
            print("Proxy Start error : \(error!)")
        }
    
        KTVHTTPCache.tokenSetURLFilter { (url) -> URL? in
            print("URL Filter reviced URL : \(url!)")
            return url
        }
        
        KTVHTTPCache.downloadSetUnsupportContentTypeFilter { (url, contentType) -> Bool in
            print("Unsupport Content-Type Filter reviced URL : \(url!) \(contentType!)")
            return false
        }
    }
}
