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
import NCCommunication

class NCViewerProviderContextMenu: UIViewController  {

    private let imageView = UIImageView()
    private var videoLayer: AVPlayerLayer?
    private var metadata: tableMetadata?
    private var metadataLivePhoto: tableMetadata?

    override func loadView() {
        view = imageView
        imageView.contentMode = .scaleAspectFit
        preferredContentSize = imageView.frame.size
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let videoLayer = self.videoLayer {
            videoLayer.frame = imageView.layer.bounds
        }
        preferredContentSize = imageView.frame.size
    }
    
    init(metadata: tableMetadata) {
        super.init(nibName: nil, bundle: nil)
        
        self.metadata = metadata
        self.metadataLivePhoto = NCManageDatabase.shared.isLivePhoto(metadata: metadata)
        
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCBrandGlobal.shared.notificationCenterDownloadedFile), object: nil)
        
        if metadata.directory {

            imageView.image = UIImage(named: "folder")!.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width / 2)
            imageView.frame = CGRect(x: 0, y: 0, width: imageView.image?.size.width ?? 0, height: imageView.image?.size.height ?? 0)

        } else {
                         
            // ICON
            if let image = UIImage.init(named: metadata.iconName)?.resizeImage(size: CGSize(width: UIScreen.main.bounds.width / 2, height: UIScreen.main.bounds.height / 2), isAspectRation: true) {
                
                imageView.image = image
                imageView.frame = CGRect(x: 0, y: 0, width: imageView.image?.size.width ?? 0, height: imageView.image?.size.height ?? 0)
            }
            
            // PREVIEW
            if CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
                
                imageView.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag))
                imageView.frame = CGRect(x: 0, y: 0, width: imageView.image?.size.width ?? 0, height: imageView.image?.size.height ?? 0)
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
            if (metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileVideo && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView)) {
                viewVideo(metadata: metadata)
            }
            
            // AUTO DOWNLOAD
            if !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                NCOperationQueue.shared.download(metadata: metadata, selector: "", setFavorite: false)
            }
            if let metadataLivePhoto = self.metadataLivePhoto {
                if !CCUtility.fileProviderStorageExists(metadataLivePhoto.ocId, fileNameView: metadataLivePhoto.fileNameView) {
                    NCOperationQueue.shared.download(metadata: metadataLivePhoto, selector: "", setFavorite: false)
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
                    }
                }
                if errorCode == 0 && metadata.ocId == self.metadataLivePhoto?.ocId {
                    viewVideo(metadata: metadata)
                }
            }
        }
    }
    
    private func viewImage(metadata: tableMetadata) {
        
        var image: UIImage?

        let ext = CCUtility.getExtension(metadata.fileNameView)
        let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        
        if ext == "GIF" {
            image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: filePath))
        } else {
            image = UIImage.init(contentsOfFile: filePath)
        }
        
        imageView.image = image
        imageView.frame = CGRect(x: 0, y: 0, width: image?.size.width ?? 0, height: image?.size.height ?? 0)
        
        preferredContentSize = imageView.frame.size
    }
    
    private func viewVideo(metadata: tableMetadata) {
        
        let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

        if let resolutionVideo = resolutionForLocalVideo(url: URL(fileURLWithPath: filePath)) {
                                
            let originRatio = resolutionVideo.width / resolutionVideo.height
            let newRatio = UIScreen.main.bounds.width / UIScreen.main.bounds.height
            var newSize = resolutionVideo
            
            if originRatio < newRatio {
                newSize.height = UIScreen.main.bounds.height
                newSize.width = UIScreen.main.bounds.height * originRatio
            } else {
                newSize.width = UIScreen.main.bounds.width
                newSize.height = UIScreen.main.bounds.width / originRatio
            }
            
            let player = AVPlayer(url: URL(fileURLWithPath: filePath))
            
            self.videoLayer = AVPlayerLayer(player: player)
            if let videoLayer = self.videoLayer {
                videoLayer.videoGravity = .resizeAspectFill
                imageView.image = nil
                imageView.frame = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
                imageView.layer.addSublayer(videoLayer)
            }
        
            player.isMuted = true
            player.play()
            
            preferredContentSize = imageView.frame.size
        }
    }
    
    private func resolutionForLocalVideo(url: URL) -> CGSize? {
        guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
