//
//  NCViewerVideoAudio.swift
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

class NCViewerVideoAudio: AVPlayerViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadata = tableMetadata()

    override func viewDidLoad() {
        super.viewDidLoad()

        var videoURL: URL?

        NCKTVHTTPCache.shared.startProxy()
        NCKTVHTTPCache.shared.saveCache(metadata: metadata)
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            
            videoURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            
        } else {
            
            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return
            }
            
            videoURL = NCKTVHTTPCache.shared.getProxyURL(stringURL: stringURL)
            NCKTVHTTPCache.shared.setAuth(user: appDelegate.user, password: appDelegate.password)
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
        NCKTVHTTPCache.shared.stopProxy()
    }
    
    //MARK: -
    
    func saveCache() {
        
        if !CCUtility.fileProviderStorageExists(self.metadata.ocId, fileNameView:self.metadata.fileNameView) {
            
            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
            
            let videoURL = URL(string: stringURL)
            guard let url = NCKTVHTTPCache.shared.getCompleteFileURL(videoURL: videoURL) else { return }
            
            CCUtility.copyFile(atPath: url.path, toPath: CCUtility.getDirectoryProviderStorageOcId(self.metadata.ocId, fileNameView: self.metadata.fileNameView))
            NCManageDatabase.sharedInstance.addLocalFile(metadata: self.metadata)
            NCKTVHTTPCache.shared.deleteCache(videoURL: videoURL)
            
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["ocId":self.metadata.ocId, "serverUrl":self.metadata.serverUrl])
        }
    }
    
    //MARK: - Observer

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath != nil && keyPath == "rate" {
            
            if player?.rate == 1 {
                print("start")
            } else {
                print("pause")
            }
            
            saveCache()
        }
    }
    
    @objc func removeObserver() {
        
        player?.removeObserver(self, forKeyPath: "rate", context: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
}
