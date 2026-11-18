// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-FileCopyrightText: 2026 Rasmus Wøldike
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import TLPhotoPicker
import Photos
import NextcloudKit
import UniformTypeIdentifiers

// MARK: - Photo Picker

@MainActor
class NCPhotosPickerViewController: NSObject {
    var controller: NCMainTabBarController
    var maxSelectedAssets = 1
    var singleSelectedMode = false
    let global = NCGlobal.shared

    var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: controller)
    }

    @discardableResult
    init(controller: NCMainTabBarController, maxSelectedAssets: Int, singleSelectedMode: Bool) {
        self.controller = controller
        super.init()
        self.maxSelectedAssets = maxSelectedAssets
        self.singleSelectedMode = singleSelectedMode

        openPhotosPickerViewController { assets in
            guard !assets.isEmpty else {
                return
            }
            let model = NCUploadAssetsModel(assets: assets, serverUrl: controller.currentServerUrl(), controller: controller)
            let view = NCUploadAssetsView(model: model)
            let viewController = UIHostingController(rootView: view)

            controller.present(viewController, animated: true, completion: nil)
        }
    }

    private func openPhotosPickerViewController(completition: @escaping ([TLPHAsset]) -> Void) {
        var configure = TLPhotosPickerConfigure()
        var pickerVC: customPhotoPickerViewController?

        configure.cancelTitle = NSLocalizedString("_cancel_", comment: "")
        configure.doneTitle = NSLocalizedString("_add_", comment: "")
        configure.emptyMessage = NSLocalizedString("_no_albums_", comment: "")
        configure.tapHereToChange = NSLocalizedString("_tap_here_to_change_", comment: "")

        if maxSelectedAssets > 0 {
            configure.maxSelectedAssets = maxSelectedAssets
        }
        configure.selectedColor = NCBrandColor.shared.getElement(account: controller.account)
        configure.singleSelectedMode = singleSelectedMode
        configure.allowedAlbumCloudShared = true
        var dateScrubber = TLDateScrubberConfigure()
        dateScrubber.minimumContentScreens = 2
        if #available(iOS 26.0, *) {
            dateScrubber.thumbColor = UIColor.secondarySystemBackground.withAlphaComponent(0.78)
            dateScrubber.labelBackgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.88)
            dateScrubber.labelTextColor = .label
        }
        configure.dateScrubber = dateScrubber

        pickerVC = customPhotoPickerViewController(withTLPHAssets: { assets in
            pickerVC?.dismiss(animated: true) {
                completition(assets)
            }
        }, didCancel: nil)
        pickerVC?.ncController = controller
        pickerVC?.didCaptureMediaURL = { [weak controller] url in
            let ext = url.pathExtension.lowercased()
            let fileType: PHAssetMediaType = ["mov", "mp4", "m4v"].contains(ext) ? .video : .image
            let originalName = fileType == .video ? "video.\(ext)" : "photo.\(ext)"
            let newFileName = NCUtilityFileSystem().createFileName(originalName, fileDate: Date(), fileType: fileType)
            let renamedURL = url.deletingLastPathComponent().appendingPathComponent(newFileName)
            try? FileManager.default.moveItem(at: url, to: renamedURL)
            guard let controller else { return }
            let model = NCUploadAssetsModel(tempAssets: [renamedURL], serverUrl: controller.currentServerUrl(), controller: controller)
            let uploadView = NCUploadAssetsView(model: model)
            controller.present(UIHostingController(rootView: uploadView), animated: true)
        }

        configure.usedCameraButton = true
        pickerVC?.configure = configure

        pickerVC?.didExceedMaximumNumberOfSelection = { _ in
            Task {
                await showErrorBanner(windowScene: self.windowScene, text: "_limited_dimension_", errorCode: NCGlobal.shared.errorInternalError)
            }
        }

        pickerVC?.handleNoAlbumPermissions = { _ in
            Task {
                await showErrorBanner(windowScene: self.windowScene, text: "_denied_album_", errorCode: NCGlobal.shared.errorForbidden)
            }
        }

        pickerVC?.handleNoCameraPermissions = { _ in
            Task {
                await showErrorBanner(windowScene: self.windowScene, text: "_denied_camera_", errorCode: NCGlobal.shared.errorForbidden)
            }
        }

        pickerVC?.configure = configure
        guard let pickerVC else {
            return
        }

        DispatchQueue.main.async {
            self.controller.present(pickerVC, animated: true, completion: nil)
        }
    }
}

class customPhotoPickerViewController: TLPhotosPickerViewController {

    var ncController: NCMainTabBarController?
    private let navigationSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    private let navigationVerticalPadding: CGFloat = 10

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Lifecycle

    override func makeUI() {
        super.makeUI()
        self.customNavItem.leftBarButtonItem?.tintColor = NCBrandColor.shared.iconImageColor
        self.customNavItem.rightBarButtonItem?.tintColor = NCBrandColor.shared.iconImageColor
        if #available(iOS 26.0, *) {
            doneButton.image = UIImage(systemName: "checkmark", withConfiguration: navigationSymbolConfiguration)
            doneButton.accessibilityLabel = configure.doneTitle
            configureAlbumTitleBackground()
            configureAlbumPopupBackground()
            configureNavigationScrollEdge()
        }
    }

    @available(iOS 26.0, *)
    private func configureAlbumPopupBackground() {
        guard let popup = albumPopView.popupView else { return }
        let corners = UICornerConfiguration.uniformCorners(radius: .fixed(24))
        popup.backgroundColor = .clear
        popup.cornerConfiguration = corners
        albumPopView.tableView.backgroundColor = .clear
        popArrowImageView.isHidden = true

        let background = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        background.cornerConfiguration = corners
        background.isUserInteractionEnabled = false
        background.translatesAutoresizingMaskIntoConstraints = false
        popup.insertSubview(background, at: 0)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: popup.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: popup.trailingAnchor),
            background.topAnchor.constraint(equalTo: popup.topAnchor),
            background.bottomAnchor.constraint(equalTo: popup.bottomAnchor)
        ])
    }

    @available(iOS 26.0, *)
    private func configureAlbumTitleBackground() {
        let background = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        background.cornerConfiguration = .capsule()
        background.isUserInteractionEnabled = false
        background.translatesAutoresizingMaskIntoConstraints = false
        titleView.insertSubview(background, at: 0)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: titleView.leadingAnchor, constant: -10),
            background.trailingAnchor.constraint(equalTo: titleView.trailingAnchor, constant: 10),
            background.topAnchor.constraint(equalTo: titleView.topAnchor),
            background.bottomAnchor.constraint(equalTo: titleView.bottomAnchor)
        ])
    }

    @available(iOS 26.0, *)
    private func configureNavigationScrollEdge() {
        guard let collectionTopConstraint = view.constraints.first(where: {
            $0.firstItem === collectionView && $0.firstAttribute == .top &&
            $0.secondItem === navigationBar && $0.secondAttribute == .bottom
        }) else { return }

        // The picker XIB starts the grid below the navigation bar.
        collectionTopConstraint.isActive = false
        collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        navigationBarTopConstraint.constant = navigationVerticalPadding
        navigationBar.isTranslucent = true
        view.bringSubviewToFront(navigationBar)

        collectionView.topEdgeEffect.style = .soft
        let interaction = UIScrollEdgeElementContainerInteraction()
        interaction.scrollView = collectionView
        interaction.edge = .top
        navigationBar.addInteraction(interaction)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyCustomButtons()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if #available(iOS 26.0, *), let albumCell = cell as? TLCollectionTableViewCell {
            albumCell.backgroundColor = .clear
            albumCell.contentView.backgroundColor = .clear
            albumCell.subTitleLabel.textColor = .secondaryLabel
            albumCell.thumbImageView.layer.cornerRadius = 10
            albumCell.thumbImageView.layer.cornerCurve = .continuous
            albumCell.thumbImageView.clipsToBounds = true
        }
        return cell
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if #available(iOS 26.0, *), navigationBar.isTranslucent {
            let topInset = navigationBar.frame.maxY - view.safeAreaInsets.top + navigationVerticalPadding
            if collectionView.contentInset.top != topInset {
                let isAtTop = collectionView.contentOffset.y <= -collectionView.adjustedContentInset.top + 1
                collectionView.contentInset.top = topInset
                if isAtTop && !collectionView.isDragging {
                    collectionView.contentOffset.y = -collectionView.adjustedContentInset.top
                }
            }
        }
        applyCustomButtons()
    }

    private func applyCustomButtons() {
        guard let navItem = self.customNavItem else { return }

        if navItem.leftBarButtonItems?.contains(where: { $0.action == #selector(customAction) }) == true {
            return
        }

        let closeBtn = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(customAction)
        )
        closeBtn.tintColor = NCBrandColor.shared.iconImageColor
        closeBtn.accessibilityLabel = configure.cancelTitle
        if #available(iOS 26.0, *) {
            closeBtn.image = UIImage(systemName: "xmark", withConfiguration: navigationSymbolConfiguration)
        }

        var leftItems: [UIBarButtonItem] = [closeBtn]

        if PHPhotoLibrary.authorizationStatus() == .limited {
            let selectPhotosBtn = UIBarButtonItem(
                image: UIImage(systemName: "photo.badge.plus"),
                style: .plain,
                target: self,
                action: #selector(selectLimitedPhotos)
            )
            selectPhotosBtn.tintColor = NCBrandColor.shared.iconImageColor
            leftItems.append(selectPhotosBtn)
        }

        navItem.leftBarButtonItems = leftItems
    }

    // MARK: - Actions

    @objc private func selectLimitedPhotos() {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
    }

    func presentUploadView(url: URL) {
        guard let controller = ncController else { return }
        let model = NCUploadAssetsModel(tempAssets: [url], serverUrl: controller.currentServerUrl(), controller: controller)
        let uploadView = NCUploadAssetsView(model: model)
        let uploadVC = UIHostingController(rootView: uploadView)
        self.dismiss(animated: true) {
            controller.present(uploadVC, animated: true)
        }
    }

    @objc private func customAction() {
        self.dismiss(animated: true)
    }
}

    // MARK: - Document Picker

    class NCDocumentPickerViewController: NSObject, UIDocumentPickerDelegate {
        let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
        let utilityFileSystem = NCUtilityFileSystem()
        let database = NCManageDatabase.shared
        let controller: NCMainTabBarController
        var viewController: UIViewController?
        var isViewerMedia: Bool

        init(controller: NCMainTabBarController, isViewerMedia: Bool, allowsMultipleSelection: Bool, viewController: UIViewController? = nil) {
            self.controller = controller
            self.isViewerMedia = isViewerMedia
            self.viewController = viewController
            super.init()

            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
            documentPicker.modalPresentationStyle = .formSheet
            documentPicker.allowsMultipleSelection = allowsMultipleSelection
            documentPicker.delegate = self
            documentPicker.popoverPresentationController?.sourceView = controller.tabBar
            documentPicker.popoverPresentationController?.sourceRect = controller.tabBar.bounds

            controller.present(documentPicker, animated: true)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            Task { @MainActor in
                let session = NCSession.shared.getSession(controller: self.controller)
                let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)

                if isViewerMedia,
                   let urlIn = urls.first,
                   let url = self.copySecurityScopedResource(url: urlIn, urlOut: FileManager.default.temporaryDirectory.appendingPathComponent(urlIn.lastPathComponent)),
                   let viewController = self.viewController {
                    let ocId = NSUUID().uuidString
                    let fileName = url.lastPathComponent
                    let metadata = await NCManageDatabaseCreateMetadata().createMetadataAsync(
                        fileName: fileName,
                        ocId: ocId,
                        serverUrl: "",
                        url: url.path,
                        session: session,
                        sceneIdentifier: self.controller.sceneIdentifier)

                    if metadata.classFile == NKTypeClassFile.unknow.rawValue {
                        metadata.classFile = NKTypeClassFile.video.rawValue
                    }

                    if let fileNameError = FileNameValidator.checkFileName(metadata.fileNameView, account: self.controller.account, capabilities: capabilities) {
                        let message = "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"
                        await UIAlertController.warningAsync(message: message, presenter: self.controller)
                    } else {
                        if let metadata = await database.addAndReturnMetadataAsync(metadata),
                           let vc = await NCViewer().getViewerController(metadata: metadata, delegate: viewController, viewerTransitionSource: nil) {
                            viewController.navigationController?.pushViewController(vc, animated: true)
                        }
                    }
                } else {
                    let serverUrl = self.controller.currentServerUrl()
                    var metadatas = [tableMetadata]()
                    var metadatasInConflict = [tableMetadata]()
                    var invalidNameIndexes: [Int] = []

                    for urlIn in urls {
                        let ocId = NSUUID().uuidString
                        let fileName = urlIn.lastPathComponent
                        let newFileName = FileAutoRenamer.rename(fileName, capabilities: capabilities)
                        let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId,
                                                                                       fileName: newFileName,
                                                                                       userId: session.userId,
                                                                                       urlBase: session.urlBase)
                        let urlOut = URL(fileURLWithPath: toPath)
                        guard self.copySecurityScopedResource(url: urlIn, urlOut: urlOut) != nil else {
                            continue
                        }
                        let metadataForUpload = await NCManageDatabaseCreateMetadata().createMetadataAsync(
                            fileName: newFileName,
                            ocId: ocId,
                            serverUrl: serverUrl,
                            url: "",
                            session: session,
                            sceneIdentifier: self.controller.sceneIdentifier)

                        metadataForUpload.session = NCNetworking.shared.sessionUploadBackground
                        metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
                        metadataForUpload.size = utilityFileSystem.getFileSize(filePath: toPath)
                        metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
                        metadataForUpload.sessionDate = Date()

                        if database.getMetadataConflict(account: session.account, serverUrl: serverUrl, fileNameView: fileName, nativeFormat: metadataForUpload.nativeFormat) != nil {
                            metadatasInConflict.append(metadataForUpload)
                        } else {
                            metadatas.append(metadataForUpload)
                        }
                    }

                    for (index, metadata) in metadatas.enumerated() {
                        if let fileNameError = FileNameValidator.checkFileName(metadata.fileName, account: session.account, capabilities: capabilities) {
                            if metadatas.count == 1 {
                                let newFileName = await UIAlertController.renameFileAsync(fileName: metadata.fileName,
                                                                                          capabilities: capabilities,
                                                                                          account: metadata.account,
                                                                                          presenter: self.controller)
                                metadatas[index].fileName = newFileName
                                metadatas[index].fileNameView = newFileName
                                metadatas[index].serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: metadatas[index].serverUrl, fileName: newFileName)
                                await self.database.addMetadatasAsync(metadatas)
                                return
                            } else {
                                let message = "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"
                                await UIAlertController.warningAsync(message: message, presenter: self.controller)
                                invalidNameIndexes.append(index)
                            }
                        }
                    }

                    for index in invalidNameIndexes.reversed() {
                        metadatas.remove(at: index)
                    }

                    await self.database.addMetadatasAsync(metadatas)

                    if !metadatasInConflict.isEmpty {
                        if let conflict = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict {
                            conflict.account = self.controller.account
                            conflict.delegate = appDelegate
                            conflict.serverUrl = serverUrl
                            conflict.metadatasUploadInConflict = metadatasInConflict
                            self.controller.present(conflict, animated: true, completion: nil)
                        }
                    }
                }
            }
        }

        func copySecurityScopedResource(url: URL, urlOut: URL) -> URL? {
            try? FileManager.default.removeItem(at: urlOut)
            if url.startAccessingSecurityScopedResource() {
                do {
                    try FileManager.default.copyItem(at: url, to: urlOut)
                    url.stopAccessingSecurityScopedResource()
                    return urlOut
                } catch {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return nil
        }
    }
