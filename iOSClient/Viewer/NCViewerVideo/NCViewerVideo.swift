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

import UIKit
import AVKit
import NCCommunication

protocol NCViewerVideoDelegate {
    func startPictureInPicture(metadata: tableMetadata)
    func stopPictureInPicture(metadata: tableMetadata, playing: Bool)
}

class NCViewerVideo: AVPlayerViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadata = tableMetadata()
    var pictureInPicture: Bool = false
    var imageBackground: UIImage?
    var delegateViewerVideo: NCViewerVideoDelegate?
    private var rateObserverToken: Any?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        func play(url: URL) {
            
            player = AVPlayer(url: url)
            
            if  metadata.typeFile == NCGlobal.shared.metadataTypeFileAudio {
                                
                let imageView = UIImageView.init(image: imageBackground)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                contentOverlayView?.addSubview(imageView)
                
                if let view = contentOverlayView {
                    NSLayoutConstraint.activate([
                        imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                        imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                        imageView.heightAnchor.constraint(equalToConstant: view.frame.height/3),
                        imageView.widthAnchor.constraint(equalToConstant: view.frame.height/3),
                    ])
                }
            }
        
            // At end go back to start
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { (notification) in
                if let item = notification.object as? AVPlayerItem, let currentItem = self.player?.currentItem, item == currentItem {
                    self.player?.seek(to: CMTime.zero)
                }
            }
        
            rateObserverToken = player?.addObserver(self, forKeyPath: "rate", options: [], context: nil)
            
            player?.play()
            if let time = NCManageDatabase.shared.getVideoTime(metadata: self.metadata) {
                player?.seek(to: time)
            }
            player?.isMuted = CCUtility.getAudioMute()
            
            // AIRPLAY
            if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                player?.allowsExternalPlayback = true
            } else {
                player?.allowsExternalPlayback = false
            }
        }
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            
            play(url: URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)))
            
        } else {
            
            NCCommunication.shared.getDirectDownload(fileId: metadata.fileId) { account, url, errorCode, errorDescription in
                
                if let url = URL(string: url) {
                    play(url: url)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: player?.currentTime())
        
        if let player = self.player {
            CCUtility.setAudioMute(player.isMuted)
        }
        
        if !pictureInPicture {
            player?.pause()
            
            if rateObserverToken != nil {
                player?.removeObserver(self, forKeyPath: "rate")
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
                self.rateObserverToken = nil
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath != nil && keyPath == "rate" {
           // NCKTVHTTPCache.shared.saveCache(metadata: metadata)
        }
    }
}

extension NCViewerVideo: AVPlayerViewControllerDelegate {
    
    func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
        true
    }
    
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        pictureInPicture = true
        delegateViewerVideo?.startPictureInPicture(metadata: metadata)
    }
    
    func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: player?.currentTime())
        pictureInPicture = false
        let playing = player?.timeControlStatus == .playing
        delegateViewerVideo?.stopPictureInPicture(metadata: metadata, playing: playing)
    }
}
