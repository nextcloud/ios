//
//  NCVideo.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/10/2020.
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

import Foundation
import KTVHTTPCache

class NCVideoViewController: AVPlayerViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadata = tableMetadata()

    override func viewDidLoad() {
        super.viewDidLoad()

        var videoURL: URL?

        setupHTTPCache()
        saveCache()
        
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
        
        if let url = videoURL {
            
            let video = AVPlayer(url: url)
            player = video
        
            // At end go back to start
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
    
    //MARK: -
    
    func saveCache() {
        
        if !CCUtility.fileProviderStorageExists(self.metadata.ocId, fileNameView:self.metadata.fileNameView) {
            
            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
            
            let videoURL = URL(string: stringURL)
            guard let url = KTVHTTPCache.cacheCompleteFileURL(with: videoURL) else { return }
            
            CCUtility.copyFile(atPath: url.path, toPath: CCUtility.getDirectoryProviderStorageOcId(self.metadata.ocId, fileNameView: self.metadata.fileNameView))
            NCManageDatabase.sharedInstance.addLocalFile(metadata: self.metadata)
            KTVHTTPCache.cacheDelete(with: videoURL)
            
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["ocId":self.metadata.ocId, "serverUrl":self.metadata.serverUrl])
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
            
            saveCache()
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
