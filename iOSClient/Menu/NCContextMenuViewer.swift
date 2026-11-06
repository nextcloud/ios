// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

/// A context menu created to be used universally with the different `NCViewer`s.
/// See ``NCViewerImage``, ``NCViewerMedia``, ``NCViewerPDF`` for usage details.
@MainActor
class NCContextMenuViewer: NSObject {
    let metadata: tableMetadata
    let controller: NCMainTabBarController?
    let viewController: UIViewController?
    let webView: Bool
    let sender: Any?
    private let database = NCManageDatabase.shared
    private let utility = NCUtility()
    private let utilityFileSystem = NCUtilityFileSystem()

    internal var windowScene: UIWindowScene? {
       SceneManager.shared.getWindowScene(controller: controller)
    }

    init(metadata: tableMetadata,
         controller: NCMainTabBarController?,
         viewController: UIViewController?,
         webView: Bool,
         sender: Any?) {
        self.metadata = metadata
        self.controller = controller
        self.viewController = viewController
        self.webView = webView
        self.sender = sender
    }

    func viewMenu() -> UIMenu? {
        guard let controller,
              let capabilities = NCNetworking.shared.capabilities[metadata.account] else {
            return nil
        }

        var topMenuItems: [UIMenuElement] = []
        var openingActions: [UIMenuElement] = []
        var editingActions: [UIMenuElement] = []
        var savingActions: [UIMenuElement] = []
        var deleteActions: [UIMenuElement] = []
        let localFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        let isOffline = localFile?.offline == true

        if !webView,
           metadata.canShare {
            topMenuItems.append(
                NCContextMenuActions.share(
                    metadatas: [metadata],
                    controller: controller,
                    presentViewController: viewController,
                    sender: sender
                )
            )
        }

        if shouldShowDetails(for: capabilities) {
            topMenuItems.append(
                NCContextMenuActions.detail(
                    metadata: metadata,
                    controller: controller,
                    presentViewController: viewController
                )
            )
        }

        if !metadata.lock {
            topMenuItems.append(NCContextMenuActions.favorite(metadata: metadata))
        }

        if !webView {
            openingActions.append(NCContextMenuActions.viewInFolder(metadata: metadata, controller: controller, viewController: viewController))
        }

        if !webView,
           metadata.isPDF {
            openingActions.append(contentsOf: makePDFActions())
        }

        if !webView,
           metadata.isRenameable {
            editingActions.append(NCContextMenuActions.rename(
                metadata: metadata,
                presenter: viewController ?? controller,
                windowScene: windowScene
            ) { [weak viewController = self.viewController] renamedMetadata in
                (viewController as? NCVideoAVPlayerViewController)?.updateMetadata(renamedMetadata)
                (viewController as? NCVideoVLCViewController)?.updateMetadata(renamedMetadata)
            })
        }

        if !webView,
           metadata.isCopyableMovable {
            editingActions.append(NCContextMenuActions.moveOrCopy(metadatas: [metadata], account: metadata.account, controller: controller))
        }

        if !webView,
           metadata.isImage,
           metadata.isModifiableWithQuickLook,
           (NCNetworking.shared.isOnline || utilityFileSystem.fileProviderStorageExists(metadata)) {
            editingActions.append(makeModifyPhoto())
        }

        if !webView,
           metadata.canSetAsAvailableOffline {
            savingActions.append(NCContextMenuActions.setAvailableOffline(metadatas: [metadata], isAnyOffline: isOffline, controller: controller))
        }

        if !webView,
           NCNetworking.shared.isOnline,
           let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            savingActions.append(NCContextMenuActions.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV, windowScene: windowScene))
        }

        if !webView,
           NCNetworking.shared.isOnline,
           metadata.isSavebleAsImage {
            savingActions.append(NCContextMenuActions.saveAsScan(metadata: metadata, sceneIdentifier: controller.sceneIdentifier))
        }

        if !webView,
           metadata.isDeletable {
            deleteActions.append(NCContextMenuActions.delete(metadatas: [metadata], controller: controller, presentViewController: viewController))
        }

        var finalMenuElements: [UIMenuElement] = []

        if let topMenu = NCContextMenuActions.inlineMenu(children: topMenuItems, preferredElementSize: .medium) {
            finalMenuElements.append(topMenu)
        }

        finalMenuElements.append(contentsOf: [openingActions, editingActions, savingActions, deleteActions]
            .compactMap { NCContextMenuActions.inlineMenu(children: $0) }
        )

        return UIMenu(title: "", children: finalMenuElements)
    }

    static func mediaNavigationItem(
        viewController: UIViewController,
        metadataProvider: @escaping () -> tableMetadata?,
        controllerProvider: @escaping () -> NCMainTabBarController?
    ) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: NCImageCache.shared.getImageButtonMore(), primaryAction: nil, menu: nil)
        item.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak viewController, weak item] completion in
                guard let viewController, let metadata = metadataProvider() else {
                    completion([])
                    return
                }

                let contextMenu = NCContextMenuViewer(metadata: metadata, controller: controllerProvider(), viewController: viewController, webView: false, sender: item)
                completion(contextMenu.mediaMenu().children)
            }
        ])
        return item
    }

    /// A standalone adaptive action; use its real button as the popover anchor.
    static func mediaActionsButton(
        viewController: UIViewController,
        metadataProvider: @escaping () -> tableMetadata?,
        controllerProvider: @escaping () -> NCMainTabBarController?
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(NCImageCache.shared.getImageButtonMore(), for: .normal)
        button.accessibilityLabel = NSLocalizedString("_more_", comment: "")
        button.showsMenuAsPrimaryAction = true
        button.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak viewController, weak button] completion in
                guard let viewController, let button, let metadata = metadataProvider() else {
                    completion([])
                    return
                }
                let contextMenu = NCContextMenuViewer(metadata: metadata, controller: controllerProvider(), viewController: viewController, webView: false, sender: button)
                completion(contextMenu.mediaMenu().children)
            }
        ])
        return button
    }

    private func mediaMenu() -> UIMenu {
        var children = viewMenu()?.children ?? []
        if let videoPlayerMenu = makeVideoPlayerMenu() {
            children.append(videoPlayerMenu)
        }
        return UIMenu(children: children)
    }

    private func makeVideoPlayerMenu() -> UIMenu? {
        let metadata = self.metadata
        guard metadata.classFile == NKTypeClassFile.video.rawValue else {
            return nil
        }

        let playback = NCVideoPlaybackController.shared

        guard playback.isCurrentVideo(
            ocId: metadata.ocId,
            etag: metadata.etag
        ) else {
            return nil
        }

        let alwaysUseVLC = NCPreferences().alwaysUseVLCForVideo(
            account: metadata.account,
            ocId: metadata.ocId
        )

        switch playback.engine {
        case .avFoundation, .vlc:
            break
        case .loading, .failed:
            return nil
        }

        let alwaysUseVLCAction = UIAction(
            title: NSLocalizedString("_always_play_with_vlc_", comment: ""),
            image: UIImage(named: "Vlc-Logo")?.withRenderingMode(.alwaysTemplate),
            state: alwaysUseVLC ? .on : .off
        ) { [weak viewController = self.viewController] _ in
            NCPreferences().setAlwaysUseVLCForVideo(
                !alwaysUseVLC,
                account: metadata.account,
                ocId: metadata.ocId
            )

            if !alwaysUseVLC, case .vlc = playback.engine {
                return
            }

            let changePlayer = {
                guard playback.isCurrentVideo(ocId: metadata.ocId, etag: metadata.etag) else { return }
                if alwaysUseVLC {
                    playback.retryAVFoundation()
                } else {
                    playback.switchToVLC()
                }
            }

            if viewController is NCVideoAVPlayerViewController {
                NCVideoAVPlayerPresenter.dismissCurrent(completion: changePlayer)
            } else if viewController is NCVideoVLCViewController {
                NCVideoVLCPresenter.dismissCurrent(completion: changePlayer)
            } else {
                changePlayer()
            }
        }

        return UIMenu(
            title: "",
            options: .displayInline,
            children: [
                alwaysUseVLCAction
            ]
        )
    }

    // MARK: - Private Action Makers

    private func shouldShowDetails(for capabilities: NKCapabilities.Capabilities) -> Bool {
        capabilities.fileSharingApiEnabled || capabilities.filesComments || !capabilities.activity.isEmpty
    }

    private func makePDFActions() -> [UIAction] {
        [
            UIAction(
                title: NSLocalizedString("_search_", comment: ""),
                image: UIImage(systemName: "magnifyingglass")
            ) { _ in
                NotificationCenter.default.postOnMainThread(
                    name: NCGlobal.shared.notificationCenterMenuSearchTextPDF
                )
            },
            UIAction(
                title: NSLocalizedString("_go_to_page_", comment: ""),
                image: UIImage(systemName: "number.circle")
            ) { _ in
                NotificationCenter.default.postOnMainThread(
                    name: NCGlobal.shared.notificationCenterMenuGotToPageInPDF
                )
            }
        ]
    }

    private func makeModifyPhoto() -> UIAction {
        let metadata = self.metadata
        return UIAction(
            title: NSLocalizedString("_edit_", comment: ""),
            image: utility.loadImage(named: "pencil.tip.crop.circle", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            Task {
                if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                    await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferChange(
                            networkingStatus: NCGlobal.shared.networkingStatusDownloaded,
                            account: metadata.account,
                            fileName: metadata.fileName,
                            serverUrl: metadata.serverUrl,
                            selector: NCGlobal.shared.selectorLoadFileQuickLook,
                            ocId: metadata.ocId,
                            destination: nil,
                            error: .success
                        )
                    }
                } else if NCNetworking.shared.isOnline,
                          let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(
                            ocId: metadata.ocId,
                            session: NCNetworking.shared.sessionDownload,
                            selector: NCGlobal.shared.selectorLoadFileQuickLook,
                            sceneIdentifier: self.controller?.sceneIdentifier
                          ) {
                    await NCNetworking.shared.downloadFile(metadata: metadata)
                }
            }
        }
    }
}
