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

    override func loadView() {
        view = imageView
    }
    
    init(metadata: tableMetadata) {
        super.init(nibName: nil, bundle: nil)
        
        var image: UIImage?
        let ext = CCUtility.getExtension(metadata.fileNameView)
        let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let imagePathPreview = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!

        imageView.contentMode = .scaleAspectFit
                
        if metadata.directory {

            imageView.image = UIImage(named: "folder")!.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width / 2)
            imageView.frame = CGRect(x: 0, y: 0, width: image?.size.width ?? 0, height: image?.size.height ?? 0)

        } else {
                            
            // PREVIEW
            if CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
                image = UIImage.init(contentsOfFile: imagePathPreview)
            }
                
            // IMAGE
            if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileImage && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                if ext == "GIF" {
                    image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: imagePath))
                } else {
                    image = UIImage.init(contentsOfFile: imagePath)
                }
            }
            
            imageView.image = image
            imageView.frame = CGRect(x: 0, y: 0, width: image?.size.width ?? 0, height: image?.size.height ?? 0)

            // VIDEO
            if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileVideo && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {

                if let resolutionVideo = resolutionForLocalVideo(url: URL(fileURLWithPath: imagePath)) {
                                        
                    let originRatio = resolutionVideo.width / resolutionVideo.height
                    let newRatio = UIScreen.main.bounds.width / UIScreen.main.bounds.height
                    var newSize = CGSize.zero
                    
                    if originRatio < newRatio {
                        newSize.height = UIScreen.main.bounds.height
                        newSize.width = UIScreen.main.bounds.height * originRatio
                    } else {
                        newSize.width = UIScreen.main.bounds.width
                        newSize.height = UIScreen.main.bounds.width / originRatio
                    }
                    
                    let player = AVPlayer(url: URL(fileURLWithPath: imagePath))
                    let videoLayer = AVPlayerLayer(player: player)
                    
                    videoLayer.frame = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
                    videoLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                         
                    imageView.frame = videoLayer.frame
                    imageView.layer.addSublayer(videoLayer)
                            
                    player.isMuted = CCUtility.getAudioMute()
                    player.play()
                }
            }
        }
        
        preferredContentSize = imageView.frame.size
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
