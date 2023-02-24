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

import UIKit
import AVFoundation
import NextcloudKit
import SVGKit

class NCViewerProviderContextMenu: UIViewController {

    private let imageView = UIImageView()
    private var videoLayer: AVPlayerLayer?
    private var audioPlayer: AVAudioPlayer?
    private var metadata: tableMetadata?
    private var metadataLivePhoto: tableMetadata?
    private var image: UIImage?

    private let sizeIcon: CGFloat = 150

    // MARK: - View Life Cycle

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(metadata: tableMetadata, image: UIImage?) {
        super.init(nibName: nil, bundle: nil)

        self.metadata = metadata
        self.metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        self.image = image

        if metadata.directory {

            var imageFolder = UIImage(named: "folder")!.image(color: NCBrandColor.shared.brandElement, size: sizeIcon*2)

            if let image = self.image {
                imageFolder =  image.image(color: NCBrandColor.shared.brandElement, size: sizeIcon*2)
            }

            imageView.image = imageFolder.colorizeFolder(metadata: metadata)
            imageView.frame = resize(CGSize(width: sizeIcon, height: sizeIcon))

        } else {

            // ICON
            if let image = UIImage(named: metadata.iconName)?.resizeImage(size: CGSize(width: sizeIcon*2, height: sizeIcon*2)) {

                imageView.image = image
                imageView.frame = resize(CGSize(width: sizeIcon, height: sizeIcon))
            }

            // PREVIEW
            if CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {

                if let image = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)) {
                    imageView.image = image
                    imageView.frame = resize(image.size)
                }
            }

            // VIEW IMAGE
            if metadata.classFile == NKCommon.TypeClassFile.image.rawValue && CCUtility.fileProviderStorageExists(metadata) {
                viewImage(metadata: metadata)
            }

            // VIEW LIVE PHOTO
            if let metadataLivePhoto = metadataLivePhoto, CCUtility.fileProviderStorageExists(metadataLivePhoto) {
                viewVideo(metadata: metadataLivePhoto)
            }

            // VIEW VIDEO
            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue && CCUtility.fileProviderStorageExists(metadata) {
                viewVideo(metadata: metadata)
            }

            // PLAY SOUND
            if metadata.classFile == NKCommon.TypeClassFile.audio.rawValue && CCUtility.fileProviderStorageExists(metadata) {
                playSound(metadata: metadata)
            }

            // AUTO DOWNLOAD VIDEO / AUDIO
            // if !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && (metadata.classFile == NKCommon.TypeClassFile.video.rawValue || metadata.classFile == NKCommon.TypeClassFile.audio.rawValue || metadata.contentType == "application/pdf") {
            if !CCUtility.fileProviderStorageExists(metadata) && (metadata.classFile == NKCommon.TypeClassFile.video.rawValue || metadata.classFile == NKCommon.TypeClassFile.audio.rawValue) {

                var maxDownload: UInt64 = 0

                if NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableCellular {
                    maxDownload = NCGlobal.shared.maxAutoDownloadCellular
                } else {
                    maxDownload = NCGlobal.shared.maxAutoDownload
                }

                if metadata.size <= maxDownload {
                    NCOperationQueue.shared.download(metadata: metadata, selector: "")
                }
            }

            // AUTO DOWNLOAD IMAGE GIF
            if !CCUtility.fileProviderStorageExists(metadata) && metadata.contentType == "image/gif" {
                NCOperationQueue.shared.download(metadata: metadata, selector: "")
            }

            // AUTO DOWNLOAD IMAGE SVG
            if !CCUtility.fileProviderStorageExists(metadata) && metadata.contentType == "image/svg+xml" {
                NCOperationQueue.shared.download(metadata: metadata, selector: "")
            }

            // AUTO DOWNLOAD LIVE PHOTO
            if let metadataLivePhoto = self.metadataLivePhoto {
                if !CCUtility.fileProviderStorageExists(metadataLivePhoto) {
                    NCOperationQueue.shared.download(metadata: metadataLivePhoto, selector: "")
                }
            }
        }
    }

    override func loadView() {
        view = imageView
        imageView.contentMode = .scaleAspectFill
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadStartFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadCancelFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile), object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile), object: nil)
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

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else { return }

        if ocId == self.metadata?.ocId || ocId == self.metadataLivePhoto?.ocId {
            NCActivityIndicator.shared.start(backgroundView: self.view)
        }
    }

    @objc func downloadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let error = userInfo["error"] as? NKError,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else { return }

        if error == .success && metadata.ocId == self.metadata?.ocId {
            if metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
                viewImage(metadata: metadata)
            } else if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                viewVideo(metadata: metadata)
            } else if metadata.classFile == NKCommon.TypeClassFile.audio.rawValue {
                playSound(metadata: metadata)
            }
        }
        if error == .success && metadata.ocId == self.metadataLivePhoto?.ocId {
            viewVideo(metadata: metadata)
        }
        if ocId == self.metadata?.ocId || ocId == self.metadataLivePhoto?.ocId {
            NCActivityIndicator.shared.stop()
        }
    }

    @objc func downloadCancelFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else { return }

        if ocId == self.metadata?.ocId || ocId == self.metadataLivePhoto?.ocId {
            NCActivityIndicator.shared.stop()
        }
    }

    // MARK: - Viewer

    private func viewImage(metadata: tableMetadata) {

        var image: UIImage?

        let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

        if metadata.contentType == "image/gif" {
            image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: filePath))
        } else if metadata.contentType == "image/svg+xml" {
            let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            if let svgImage = SVGKImage(contentsOfFile: imagePath) {
                svgImage.size = CGSize(width: NCGlobal.shared.sizePreview, height: NCGlobal.shared.sizePreview)
                image = svgImage.uiImage
            }
        } else {
            image = UIImage(contentsOfFile: filePath)
        }

        imageView.image = image
        imageView.frame = resize(image?.size)
    }

    func playSound(metadata: tableMetadata) {

        let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

        do {
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

        let originRatio = size.width / size.height
        let newRatio = UIScreen.main.bounds.width / UIScreen.main.bounds.height
        var newSize = CGSize.zero

        if originRatio < newRatio {
            newSize.height = UIScreen.main.bounds.height
            newSize.width = UIScreen.main.bounds.height * originRatio
        } else {
            newSize.width = UIScreen.main.bounds.width
            newSize.height = UIScreen.main.bounds.width / originRatio
        }

        frame = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        preferredContentSize = frame.size
        return frame
    }
}
