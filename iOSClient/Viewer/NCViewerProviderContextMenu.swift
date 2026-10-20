// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class NCViewerProviderContextMenu: UIViewController {
    private let imageView = UIImageView()
    private var metadata: tableMetadata?
    private let utilityFileSystem = NCUtilityFileSystem()
    private let networking = NCNetworking.shared
    internal let global = NCGlobal.shared
    private let sizeIcon: CGFloat = 150
    private weak var sourceView: UIView?
    private var previewSize: CGSize?
    internal var sceneIdentifier: String = ""

    // MARK: - View Life Cycle

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(metadata: tableMetadata, image: UIImage?, sceneIdentifier: String, sourceView: UIView) {
        super.init(nibName: nil, bundle: nil)
        self.metadata = metadata.detachedCopy()
        self.sceneIdentifier = sceneIdentifier
        self.sourceView = sourceView

        if metadata.directory {
            imageView.image = NCImageCache.shared.getFolder(account: metadata.account)
            imageView.frame = resize(CGSize(width: sizeIcon, height: sizeIcon))
        } else {
            // ICON
            let icon = NCUtility().loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
            imageView.image = icon
            imageView.frame = resize(CGSize(width: sizeIcon, height: sizeIcon))
            // PREVIEW
            let thumbnail = image ?? NCUtility().getImage(
                ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt512,
                userId: metadata.userId, urlBase: metadata.urlBase
            )
            if let thumbnail {
                imageView.image = thumbnail
                imageView.frame = resize(thumbnail.size)
            }
            // VIEW IMAGE
            if metadata.isImage && utilityFileSystem.fileProviderStorageExists(metadata) {
                Task {@MainActor in
                    await viewImage(metadata: metadata)
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
        }
    }

    override func loadView() {
        view = imageView
        imageView.contentMode = .scaleAspectFill
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // UIKit owns the presented view's frame; only update its preferred size.
        let size = previewSize.map(fittedPreviewSize) ?? .zero
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
        Task { @MainActor [weak self] in
            guard let self, ocId == metadata?.ocId, metadata?.isImage == true else { return }
            if error != .success {
                let windowScene = SceneManager.shared.getWindow(sceneIdentifier: sceneIdentifier)?.windowScene
                await showErrorBanner(windowScene: windowScene, text: error.errorDescription, errorCode: error.errorCode)
            }

            switch networkingStatus {
            // DOWNLOAD
            case self.global.networkingStatusDownloading:
                NCActivityIndicator.shared.start(backgroundView: view)
            case self.global.networkingStatusDownloaded:
                if error == .success,
                   let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId),
                   metadata.isImage {
                    await viewImage(metadata: metadata)
                }
                NCActivityIndicator.shared.stop()
            case self.global.networkingStatusDownloadCancel:
                NCActivityIndicator.shared.stop()
            default:
                break
            }
        }
    }
}
