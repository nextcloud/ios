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
import NextcloudKit
import SVGKit
import MobileVLCKit

class NCViewerProviderContextMenu: UIViewController {

    private let imageView = UIImageView()
    private var metadata: tableMetadata?
    private var metadataLivePhoto: tableMetadata?
    private var image: UIImage?
    private let player = VLCMediaPlayer()
    private let utilityFileSystem = NCUtilityFileSystem()
    private let sizeIcon: CGFloat = 150

    // MARK: - View Life Cycle

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(metadata: tableMetadata, image: UIImage?) {
        super.init(nibName: nil, bundle: nil)

        self.metadata = tableMetadata(value: metadata)
        self.metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        self.image = image

        if metadata.directory {

            imageView.image = NCImageCache.images.folder.colorizeFolder(metadata: metadata)
            imageView.frame = resize(CGSize(width: sizeIcon, height: sizeIcon))

        } else {

            // ICON
            let image = NCUtility().loadImage(named: metadata.iconName, useTypeIconFile: true)
            imageView.image = image
            imageView.frame = resize(CGSize(width: sizeIcon, height: sizeIcon))

            // PREVIEW
            if utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {

                if let image = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)) {
                    imageView.image = image
                    imageView.frame = resize(image.size)
                }
            }

            // VIEW IMAGE
            if metadata.isImage && utilityFileSystem.fileProviderStorageExists(metadata) {
                viewImage(metadata: metadata)
            }

            // VIEW LIVE PHOTO
            if let metadataLivePhoto = metadataLivePhoto, utilityFileSystem.fileProviderStorageExists(metadataLivePhoto) {
                viewVideo(metadata: metadataLivePhoto)
            }

            // VIEW VIDEO
            if metadata.isVideo {
                if !utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
                    let newSize = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    imageView.image = nil
                    imageView.frame = newSize
                    preferredContentSize = newSize.size
                }
                viewVideo(metadata: metadata)
            }

            // PLAY AUDIO
            if metadata.isAudio {

                var maxDownload: UInt64 = 0

                if utilityFileSystem.fileProviderStorageExists(metadata) {

                    viewVideo(metadata: metadata)

                } else {

                    if NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableCellular {
                        maxDownload = NCGlobal.shared.maxAutoDownloadCellular
                    } else {
                        maxDownload = NCGlobal.shared.maxAutoDownload
                    }

                    if metadata.size <= maxDownload,
                       NCNetworking.shared.downloadQueue.operations.filter({ ($0 as? NCOperationDownload)?.metadata.ocId == metadata.ocId }).isEmpty {
                        NCNetworking.shared.downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: ""))
                    }
                }
            }

            // AUTO DOWNLOAD IMAGE GIF
            if !utilityFileSystem.fileProviderStorageExists(metadata),
               metadata.contentType == "image/gif",
               NCNetworking.shared.downloadQueue.operations.filter({ ($0 as? NCOperationDownload)?.metadata.ocId == metadata.ocId }).isEmpty {
                NCNetworking.shared.downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: ""))
            }

            // AUTO DOWNLOAD IMAGE SVG
            if !utilityFileSystem.fileProviderStorageExists(metadata),
               metadata.contentType == "image/svg+xml",
               NCNetworking.shared.downloadQueue.operations.filter({ ($0 as? NCOperationDownload)?.metadata.ocId == metadata.ocId }).isEmpty {
                NCNetworking.shared.downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: ""))
            }

            // AUTO DOWNLOAD LIVE PHOTO
            if let metadataLivePhoto = self.metadataLivePhoto,
               !utilityFileSystem.fileProviderStorageExists(metadataLivePhoto),
               NCNetworking.shared.downloadQueue.operations.filter({ ($0 as? NCOperationDownload)?.metadata.ocId == metadata.ocId }).isEmpty {
                NCNetworking.shared.downloadQueue.addOperation(NCOperationDownload(metadata: metadataLivePhoto, selector: ""))
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

        player.stop()

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile), object: nil)
    }

    // MARK: - NotificationCenter

    @objc func downloadStartFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else { return }

        if ocId == self.metadata?.ocId || ocId == self.metadataLivePhoto?.ocId {
            DispatchQueue.main.async { NCActivityIndicator.shared.start(backgroundView: self.view) }
        }
    }

    @objc func downloadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let error = userInfo["error"] as? NKError,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else { return }

        if error == .success && metadata.ocId == self.metadata?.ocId {
            if metadata.isImage {
                DispatchQueue.main.async {
                    self.viewImage(metadata: metadata)
                }
            } else if metadata.isVideo {
                viewVideo(metadata: metadata)
            } else if metadata.isAudio {
                viewVideo(metadata: metadata)
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

        let filePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

        if metadata.contentType == "image/gif" {
            image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: filePath))
        } else if metadata.contentType == "image/svg+xml" {
            let imagePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
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

    private func viewVideo(metadata: tableMetadata) {

        NCNetworking.shared.getVideoUrl(metadata: metadata) { url, _, _ in
            if let url = url {
                self.player.media = VLCMedia(url: url)
                self.player.delegate = self
                self.player.media?.addOption(":http-user-agent=\(userAgent)")
                self.player.drawable = self.imageView
                self.player.play()
            }
        }
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

extension NCViewerProviderContextMenu: VLCMediaPlayerDelegate {

    func mediaPlayerStateChanged(_ aNotification: Notification) {

        switch player.state {
        case .stopped:
            print("Played mode: STOPPED")
        case .opening:
            NCActivityIndicator.shared.start(backgroundView: self.view)
            print("Played mode: OPENING")
        case .buffering:
            print("Played mode: BUFFERING")
        case .ended:
            print("Played mode: ENDED")
        case .error:
            NCActivityIndicator.shared.stop()
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_error_something_wrong_")
            NCContentPresenter().showError(error: error, priority: .max)
            print("Played mode: ERROR")
        case .playing:
            NCActivityIndicator.shared.stop()
            print("Played mode: PLAYING")
        case .paused:
            print("Played mode: PAUSED")
        default: break
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        // Handle other states...
    }

    func mediaPlayerTitleChanged(_ aNotification: Notification) {
        // Handle other states...
    }

    func mediaPlayerChapterChanged(_ aNotification: Notification) {
        // Handle other states...
    }

    func mediaPlayerLoudnessChanged(_ aNotification: Notification) {
        // Handle other states...
    }

    func mediaPlayerSnapshot(_ aNotification: Notification) {
        // Handle other states...
    }

    func mediaPlayerStartedRecording(_ player: VLCMediaPlayer) {
        // Handle other states...
    }

    func mediaPlayer(_ player: VLCMediaPlayer, recordingStoppedAtPath path: String) {
        // Handle other states...
    }
}
