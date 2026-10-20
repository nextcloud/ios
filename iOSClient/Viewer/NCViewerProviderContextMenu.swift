// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import MobileVLCKit

class NCViewerProviderContextMenu: UIViewController {
    private let imageView = UIImageView()
    private var metadata: tableMetadata?
    private var metadataLivePhoto: tableMetadata?
    private var image: UIImage?
    private let player = VLCMediaPlayer()
    private let utilityFileSystem = NCUtilityFileSystem()
    private let networking = NCNetworking.shared
    internal let global = NCGlobal.shared
    private let sizeIcon: CGFloat = 150
    private weak var sourceView: UIView?
    private var previewSize: CGSize?
    private var usesAvailablePreviewSize = false
    internal var sceneIdentifier: String = ""

    // MARK: - View Life Cycle

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(metadata: tableMetadata, image: UIImage?, sceneIdentifier: String, sourceView: UIView) {
        super.init(nibName: nil, bundle: nil)
        self.metadata = metadata.detachedCopy()
        self.metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        self.image = image
        self.sceneIdentifier = sceneIdentifier
        self.sourceView = sourceView

        if metadata.directory {
            imageView.image = NCImageCache.shared.getFolder(account: metadata.account)
            imageView.frame = resize(CGSize(width: sizeIcon, height: sizeIcon))
        } else {
            // ICON
            let image = NCUtility().loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
            imageView.image = image
            imageView.frame = resize(CGSize(width: sizeIcon, height: sizeIcon))
            // PREVIEW
            if let image = NCUtility().getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt512, userId: metadata.userId, urlBase: metadata.urlBase) {
                imageView.image = image
                imageView.frame = resize(image.size)
            }
            // VIEW IMAGE
            if metadata.isImage && utilityFileSystem.fileProviderStorageExists(metadata) {
                Task {@MainActor in
                    await viewImage(metadata: metadata)
                }
            }
            // VIEW LIVE PHOTO
            if let metadataLivePhoto = metadataLivePhoto, utilityFileSystem.fileProviderStorageExists(metadataLivePhoto) {
                viewVideo(metadata: metadataLivePhoto)
            }
            // VIEW VIDEO
            if metadata.isVideo {
                if !NCUtility().existsImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt512, userId: metadata.userId, urlBase: metadata.urlBase) {
                    usesAvailablePreviewSize = true
                    let newSize = resize(availablePreviewSize)
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
                    if self.networking.networkReachability == NKTypeReachability.reachableCellular {
                        maxDownload = NCGlobal.shared.maxAutoDownloadCellular
                    } else {
                        maxDownload = NCGlobal.shared.maxAutoDownload
                    }
                    if metadata.size <= maxDownload {
                        Task {
                            if let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(
                                ocId: metadata.ocId,
                                session: self.networking.sessionDownload,
                                selector: "") {
                                await self.networking.downloadFile(metadata: metadata)
                            }
                        }
                    }
                }
            }
            // DOWNLOAD IMAGE GIF SVG
            if !utilityFileSystem.fileProviderStorageExists(metadata),
               self.networking.isOnline,
               metadata.contentType == "image/gif" || metadata.contentType == "image/svg+xml" {
                Task {
                    if let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(
                        ocId: metadata.ocId,
                        session: self.networking.sessionDownload,
                        selector: "") {
                        await self.networking.downloadFile(metadata: metadata)
                    }
                }
            }
            // DOWNLOAD LIVE PHOTO
            if let metadataLivePhoto = self.metadataLivePhoto,
               self.networking.isOnline,
               !utilityFileSystem.fileProviderStorageExists(metadataLivePhoto) {
                Task {
                    if let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(
                        ocId: metadataLivePhoto.ocId,
                        session: self.networking.sessionDownload,
                        selector: "") {
                        await self.networking.downloadFile(metadata: metadata)
                    }
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

        // UIKit owns the presented view's frame; only update its preferred size.
        let size = usesAvailablePreviewSize ? availablePreviewSize : previewSize.map(fittedPreviewSize) ?? .zero
        if preferredContentSize != size {
            preferredContentSize = size
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task {
            await NCNetworking.shared.transferDispatcher.addDelegate(self)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        player.stop()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        Task {
            await NCNetworking.shared.transferDispatcher.removeDelegate(self)
        }
    }

    // MARK: - Viewer

    private func viewImage(metadata: tableMetadata) async {
        var image: UIImage?
        let filePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                         fileName: metadata.fileNameView,
                                                                         userId: metadata.userId,
                                                                         urlBase: metadata.urlBase)

        if metadata.contentType == "image/gif" {
            image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: filePath))
        } else if metadata.contentType == "image/svg+xml" {
            let imagePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                              fileName: metadata.fileNameView,
                                                                              userId: metadata.userId,
                                                                              urlBase: metadata.urlBase)
            do {
                let url = URL(fileURLWithPath: imagePath)
                let data = try Data(contentsOf: url)
                image = try await NCSVGRenderer().renderSVGToUIImage(
                    svgData: data,
                    size: CGSize(width: 1024, height: 1024),
                    backgroundColor: .clear
                )
            } catch {
                print("SVG render error: \(error.localizedDescription)")
            }
        } else {
            image = UIImage(contentsOfFile: filePath)
        }

        imageView.image = image
        let frame = resize(image?.size)
        if imageView.window == nil {
            imageView.frame = frame
        }
    }

    private func viewVideo(metadata: tableMetadata) {
        self.networking.getVideoUrl(metadata: metadata) { url, _, _ in
            if let url = url {
                self.player.media = VLCMedia(url: url)
                self.player.delegate = self
                self.player.media?.addOption(":http-user-agent=\(userAgent)")
                self.player.drawable = self.imageView
                self.player.play()
            }
        }
    }

    private var availablePreviewSize: CGSize {
        guard let sourceView else { return .zero }
        let safeSize = sourceView.safeAreaLayoutGuide.layoutFrame.size
        return safeSize.width > 0 && safeSize.height > 0 ? safeSize : sourceView.bounds.size
    }

    private func fittedPreviewSize(_ size: CGSize) -> CGSize {
        let availableSize = availablePreviewSize
        guard size.width > 0, size.height > 0, availableSize.width > 0, availableSize.height > 0 else { return .zero }

        let scale = min(1, min(availableSize.width / size.width, availableSize.height / size.height))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    private func resize(_ size: CGSize?) -> CGRect {
        previewSize = size
        preferredContentSize = size.map(fittedPreviewSize) ?? .zero
        return CGRect(origin: .zero, size: preferredContentSize)
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
            Task {
                let windowScene = SceneManager.shared.getWindow(sceneIdentifier: self.sceneIdentifier)?.windowScene
                await showErrorBanner(windowScene: windowScene, text: "_error_something_wrong_", errorCode: NCGlobal.shared.errorInternalError)
            }
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

extension NCViewerProviderContextMenu: NCTransferDelegate {
    func transferReloadData(serverUrl: String?) { }

    func transferReloadDataSource(serverUrl: String?, requestData: Bool, status: Int?) { }

    func transferProgressDidUpdate(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) { }

    func transferChange(networkingStatus: String,
                        account: String,
                        fileName: String,
                        serverUrl: String,
                        selector: String?,
                        ocId: String,
                        destination: String?,
                        error: NKError) {
        if error != .success {
            Task {
                let windowScene = SceneManager.shared.getWindow(sceneIdentifier: self.sceneIdentifier)?.windowScene
                await showErrorBanner(windowScene: windowScene, text: error.errorDescription, errorCode: error.errorCode)
            }
        }

        Task {@MainActor in
            switch networkingStatus {
            // DOWNLOAD
            case self.global.networkingStatusDownloading:
                if ocId == self.metadata?.ocId || ocId == self.metadataLivePhoto?.ocId {
                    NCActivityIndicator.shared.start(backgroundView: self.view)
                }
            case self.global.networkingStatusDownloaded:
                if error == .success,
                   ocId == self.metadata?.ocId,
                   let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId) {
                    if metadata.isImage {
                        await self.viewImage(metadata: metadata)
                    } else if metadata.isVideo || metadata.isAudio {
                        self.viewVideo(metadata: metadata)
                    }
                }
                if error == .success,
                   ocId == self.metadataLivePhoto?.ocId,
                   let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId) {
                    self.viewVideo(metadata: metadata)
                }
                if ocId == self.metadata?.ocId || ocId == self.metadataLivePhoto?.ocId {
                    NCActivityIndicator.shared.stop()
                }
            case self.global.networkingStatusDownloadCancel:
                if ocId == self.metadata?.ocId || ocId == self.metadataLivePhoto?.ocId {
                    NCActivityIndicator.shared.stop()
                }
            default:
                break
            }
        }
    }
}
