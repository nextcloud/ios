//
//  NCViewerProviderContextMenu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/01/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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
import AVFoundation
import NCCommunication

class NCViewerProviderContextMenu: UIViewController  {

    private let imageView = UIImageView()
    private var videoLayer: AVPlayerLayer?
    private var audioPlayer: AVAudioPlayer?
    private var metadata: tableMetadata?
    private var metadataLivePhoto: tableMetadata?
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(metadata: tableMetadata) {
        super.init(nibName: nil, bundle: nil)
        
        self.metadata = metadata
        self.metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        
        NotificationCenter.default.addObserver(self, selector: #selector(downloadStartFile(_:)), name: NSNotification.Name(rawValue: NCBrandGlobal.shared.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCBrandGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadCancelFile(_:)), name: NSNotification.Name(rawValue: NCBrandGlobal.shared.notificationCenterDownloadCancelFile), object: nil)
        
        if metadata.directory {

            let image = UIImage(named: "folder")!.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width / 2)
            imageView.image = image
            imageView.frame = resize(image.size)

        } else {
                         
            // ICON
            if let image = UIImage.init(named: metadata.iconName)?.resizeImage(size: CGSize(width: UIScreen.main.bounds.width / 2, height: UIScreen.main.bounds.height / 2), isAspectRation: true) {
                
                imageView.image = image
                imageView.frame = resize(image.size)
            }
            
            // PREVIEW
            if CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
                
                if let image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)) {
                    imageView.image = image
                    imageView.frame = resize(image.size)
                }
            }
             
            // VIEW IMAGE
            if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileImage && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                
                viewImage(metadata: metadata)
            }

            // VIEW LIVE PHOTO
            if metadataLivePhoto != nil && CCUtility.fileProviderStorageExists(metadataLivePhoto!.ocId, fileNameView: metadataLivePhoto!.fileNameView) {
                
                viewVideo(metadata: metadataLivePhoto!)
            }
            
            // VIEW VIDEO
            if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileVideo && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                viewVideo(metadata: metadata)
            }
            
            // PLAY SOUND
            if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileAudio && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                playSound(metadata: metadata)
            }
            
            // AUTO DOWNLOAD VIDEO / AUDIO
            if !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && (metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileVideo || metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileAudio) {
                
                var maxDownload: UInt64 = 0
                
                if NCNetworking.shared.networkReachability == NCCommunicationCommon.typeReachability.reachableCellular {
                    maxDownload = NCBrandGlobal.shared.maxAutoDownloadCellular
                } else {
                    maxDownload = NCBrandGlobal.shared.maxAutoDownload
                }
                
                if metadata.size <= maxDownload {
                    NCOperationQueue.shared.download(metadata: metadata, selector: "")
                }
            }
            
            // AUTO DOWNLOAD IMAGE GIF
            if !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && metadata.contentType == "image/gif" {
                NCOperationQueue.shared.download(metadata: metadata, selector: "")
            }
            
            // AUTO DOWNLOAD LIVE PHOTO
            if let metadataLivePhoto = self.metadataLivePhoto {
                if !CCUtility.fileProviderStorageExists(metadataLivePhoto.ocId, fileNameView: metadataLivePhoto.fileNameView) {
                    NCOperationQueue.shared.download(metadata: metadataLivePhoto, selector: "")
                }
            }
        }
    }
    
    override func loadView() {
        view = imageView
        imageView.contentMode = .scaleAspectFill
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let videoLayer = self.videoLayer {
            if videoLayer.frame == CGRect.zero {
                videoLayer.frame = imageView.frame
            } else {
                imageView.frame = videoLayer.frame
            }
        }
        preferredContentSize = imageView.frame.size
    }
    
    // MARK: - NotificationCenter

    @objc func downloadStartFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String {
                if ocId == self.metadata?.ocId || ocId == self.metadataLivePhoto?.ocId {
                    NCUtility.shared.startActivityIndicator(view: self.view)
                }
            }
        }
    }
    
    @objc func downloadedFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId), let errorCode = userInfo["errorCode"] as? Int {
                if errorCode == 0 && metadata.ocId == self.metadata?.ocId {
                    if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileImage {
                        viewImage(metadata: metadata)
                    } else if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileVideo {
                        viewVideo(metadata: metadata)
                    } else if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileAudio {
                        playSound(metadata: metadata)
                    }
                }
                if errorCode == 0 && metadata.ocId == self.metadataLivePhoto?.ocId {
                    viewVideo(metadata: metadata)
                }
                if ocId == self.metadata?.ocId || ocId == self.metadataLivePhoto?.ocId {
                    NCUtility.shared.stopActivityIndicator()
                }
            }
        }
    }
    
    @objc func downloadCancelFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String {
                if ocId == self.metadata?.ocId || ocId == self.metadataLivePhoto?.ocId {
                    NCUtility.shared.stopActivityIndicator()
                }
            }
        }
    }
    
    // MARK: - Viewer
    
    private func viewImage(metadata: tableMetadata) {
        
        var image: UIImage?

        let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        
        if metadata.contentType == "image/gif" {
            image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: filePath))
        } else {
            image = UIImage.init(contentsOfFile: filePath)
        }

        imageView.image = image
        imageView.frame = resize(image?.size)
    }
    
    func playSound(metadata: tableMetadata) {
        
        let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: filePath), fileTypeHint: AVFileType.mp3.rawValue)

            guard let player = audioPlayer else { return }

            player.play()

        } catch let error {
            print(error.localizedDescription)
        }
        
        preferredContentSize = imageView.frame.size
    }
    
    private func viewVideo(metadata: tableMetadata) {
        
        let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

        if let resolutionVideo = resolutionForLocalVideo(url: URL(fileURLWithPath: filePath)) {
                               
            let player = AVPlayer(url: URL(fileURLWithPath: filePath))
            
            self.videoLayer = AVPlayerLayer(player: player)
            if let videoLayer = self.videoLayer {
                videoLayer.videoGravity = .resizeAspectFill
                imageView.image = nil
                imageView.frame = resize(resolutionVideo)
                imageView.layer.addSublayer(videoLayer)
            }
        
            player.isMuted = true
            player.play()
        }
    }
    
    private func resolutionForLocalVideo(url: URL) -> CGSize? {
        guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    private func resize(_ size: CGSize?) -> CGRect {
        
        var height = UIScreen.main.bounds.height/2
        var width = UIScreen.main.bounds.width/2
        var frame = CGRect.zero
        
        guard let size = size else {
            preferredContentSize = frame.size
            return frame
        }
        
        if size.width <= UIScreen.main.bounds.width { 
            frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            preferredContentSize = frame.size
            return frame
        }
        
        if size.width >= size.height {
            height = UIScreen.main.bounds.height
            width = UIScreen.main.bounds.width
        }
        
        let originRatio = size.width / size.height
        let newRatio = UIScreen.main.bounds.width / UIScreen.main.bounds.height
        var newSize = CGSize.zero
        
        if originRatio < newRatio {
            newSize.height = height
            newSize.width = height * originRatio
        } else {
            newSize.width = width
            newSize.height = width / originRatio
        }
        
        frame = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        preferredContentSize = frame.size
        return frame
    }
}
