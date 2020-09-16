//
//  NCViewerVideo.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/09/18.
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
import KTVHTTPCache

class NCViewerVideo: NSObject {
    @objc static let sharedInstance: NCViewerVideo = {
        let viewVideo = NCViewerVideo()
        viewVideo.setupHTTPCache()
        return viewVideo
    }()
    
    var metadata: tableMetadata!
    var videoURL: URL?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
   
    @objc func viewMedia(_ metadata: tableMetadata, view: UIView, frame: CGRect) {
        
        var videoURLProxy: URL!

        self.metadata = metadata
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
        
            self.videoURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            videoURLProxy = videoURL
        
        } else {
            
            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return
            }
            
            self.videoURL = URL(string: stringURL)
            videoURLProxy = KTVHTTPCache.proxyURL(withOriginalURL: self.videoURL)
            
            guard let authData = (appDelegate.user + ":" + appDelegate.password).data(using: .utf8) else {
                return
            }
            
            let authValue = "Basic " + authData.base64EncodedString(options: [])
            KTVHTTPCache.downloadSetAdditionalHeaders(["Authorization":authValue, "User-Agent":CCUtility.getUserAgent()])
        }
        
        appDelegate.player = AVPlayer(url: videoURLProxy)
        appDelegate.playerController = AVPlayerViewController()
        
        appDelegate.playerController.player = appDelegate.player
        appDelegate.playerController.view.frame = frame
        appDelegate.playerController.allowsPictureInPicturePlayback = false
        
        view.addSubview(appDelegate.playerController.view)
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) { (notification) in
            let player = notification.object as! AVPlayerItem
            player.seek(to: CMTime.zero, completionHandler: nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            
            self.appDelegate.player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
            self.appDelegate.isMediaObserver = true
            
            self.appDelegate.player.play()
        }
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
                
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["ocId":self.metadata.ocId, "serverUrl":self.metadata.serverUrl])
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
