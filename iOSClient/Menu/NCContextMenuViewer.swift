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
        var menuElements: [UIMenuElement] = []
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
            menuElements.append(makeViewInFolderAction(metadata: metadata, controller: controller, viewController: viewController))
        }

        if !webView,
           metadata.canSetAsAvailableOffline {
            menuElements.append(NCContextMenuActions.setAvailableOffline(metadatas: [metadata], isAnyOffline: isOffline, controller: controller))
        }

        if !webView,
           NCNetworking.shared.isOnline,
           metadata.isSavebleAsImage {
            menuElements.append(NCContextMenuActions.saveAsScan(metadata: metadata, sceneIdentifier: controller.sceneIdentifier))
        }

        if !webView,
           metadata.isRenameable {
            menuElements.append(NCContextMenuActions.rename(metadata: metadata, presenter: viewController ?? controller, windowScene: windowScene))
        }

        if !webView,
           metadata.isCopyableMovable {
            menuElements.append(NCContextMenuActions.moveOrCopy(metadatas: [metadata], account: metadata.account, controller: controller))
        }

        if !webView,
           NCNetworking.shared.isOnline,
           let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            menuElements.append(NCContextMenuActions.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV, windowScene: windowScene))
        }

        if !webView,
           metadata.isPDF {
            menuElements.append(contentsOf: makePDFActions())
        }

        if !webView,
           metadata.isImage,
           utilityFileSystem.fileSizeIfExists(metadata) {
            menuElements.append(makeModifyPhoto())
        }

        if !webView,
           metadata.isDeletable {
            menuElements.append(UIMenu(options: .displayInline, children: [
                NCContextMenuActions.delete(metadatas: [metadata], controller: controller)
            ]))
        }

        var finalMenuElements: [UIMenuElement] = []

        if let topMenu = NCContextMenuActions.inlineMenu(children: topMenuItems, preferredElementSize: .medium) {
            finalMenuElements.append(topMenu)
        }

        if let baseMenu = NCContextMenuActions.inlineMenu(children: menuElements) {
            finalMenuElements.append(baseMenu)
        }

        return UIMenu(title: "", children: finalMenuElements)
    }

    // MARK: - Private Action Makers

    private func shouldShowDetails(for capabilities: NKCapabilities.Capabilities) -> Bool {
        capabilities.fileSharingApiEnabled || capabilities.filesComments || !capabilities.activity.isEmpty
    }

    private func makeViewInFolderAction(metadata: tableMetadata, controller: NCMainTabBarController, viewController: UIViewController?) -> UIAction {
        UIAction(
            title: NSLocalizedString("_view_in_folder_", comment: ""),
            image: UIImage(systemName: "questionmark.folder")
        ) { _ in
            Task {
                if let files = await NCNetworking.shared.moveInFolder(serverUrl: metadata.serverUrl,
                                                                      sceneIdentifier: controller.sceneIdentifier) {

                    files.loadViewIfNeeded()
                    files.view.layoutIfNeeded()
                    files.collectionView.layoutIfNeeded()

                    if let mediaViewer = viewController as? NCMediaViewerHostingController {
                        mediaViewer.close()
                    } else if let mediaViewer = viewController as? NCVideoVLCViewController {
                        mediaViewer.closeImmediately()
                    } else if let mediaViewer = viewController as? NCVideoAVPlayerViewController {
                        mediaViewer.closeImmediately()
                    }

                    try? await Task.sleep(for: .seconds(0.6))
                    files.blinkItem(ocId: metadata.ocId)
                }
            }
        }
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
        return UIAction(
            title: NSLocalizedString("_modify_", comment: ""),
            image: utility.loadImage(named: "pencil.tip.crop.circle", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            Task {
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(
                        networkingStatus: NCGlobal.shared.networkingStatusDownloaded,
                        account: self.metadata.account,
                        fileName: self.metadata.fileName,
                        serverUrl: self.metadata.serverUrl,
                        selector: NCGlobal.shared.selectorLoadFileQuickLook,
                        ocId: self.metadata.ocId,
                        destination: nil,
                        error: .success
                    )
                }
            }
        }
    }
}
