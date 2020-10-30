//
//  NCViewerVideo.swift
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

protocol NCViewerVideoDelegate {
    func stopPictureInPicture(metadata: tableMetadata)
    func startPictureInPicture(metadata: tableMetadata)
    func playerCurrentTime(_ time: CMTime?)
}

@objc class NCViewerVideo: AVPlayerViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadata = tableMetadata()
    var seekTime: CMTime?
    var pictureInPicture: Bool = false
    var delegateViewerVideo: NCViewerVideoDelegate?
    private var rateObserverToken: Any?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var videoURL: URL?

        NCKTVHTTPCache.shared.startProxy(user: appDelegate.user, password: appDelegate.password, metadata: metadata)
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            
            videoURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            
        } else {
            
            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return
            }
            
            allowsPictureInPicturePlayback = false
            videoURL = NCKTVHTTPCache.shared.getProxyURL(stringURL: stringURL)
        }
        
        if let url = videoURL {
            
            player = AVPlayer(url: url)
        
            // At end go back to start
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) { (notification) in
                self.player?.seek(to: CMTime.zero)
            }
        
            rateObserverToken = player?.addObserver(self, forKeyPath: "rate", options: [], context: nil)
            player?.play()
            if seekTime != nil {
                player?.seek(to: seekTime!)
                seekTime = nil
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if !pictureInPicture {
            player?.pause()
            
            if rateObserverToken != nil {
                player?.removeObserver(self, forKeyPath: "rate")
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
                NCKTVHTTPCache.shared.stopProxy()
                self.delegateViewerVideo?.playerCurrentTime(player?.currentTime())
                self.rateObserverToken = nil
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath != nil && keyPath == "rate" {
            NCKTVHTTPCache.shared.saveCache(metadata: metadata)
        }
    }
}

extension NCViewerVideo: AVPlayerViewControllerDelegate {
    
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        pictureInPicture = true
        delegateViewerVideo?.startPictureInPicture(metadata: metadata)
    }
    
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        pictureInPicture = false
        delegateViewerVideo?.stopPictureInPicture(metadata: metadata)
    }
}
