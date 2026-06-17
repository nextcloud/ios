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
        guard let metadata = database.getMetadataFromOcId(metadata.ocId),
              let controller,
              let capabilities = NCNetworking.shared.capabilities[metadata.account] else {
            return nil
        }

        var topMenuItems: [UIMenuElement] = []
        var menuElements: [UIMenuElement] = []
        let localFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        let isOffline = localFile?.offline == true

        // SHARE
        if !webView, metadata.canShare {
            topMenuItems.append(ContextMenuActions.share(metadatas: [metadata], controller: controller, presentViewController: viewController, sender: sender))
        }

        // DETAIL
        if !(!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty) {
            topMenuItems.append(makeDetailAction(metadata: metadata, controller: controller, presentViewController: viewController))
        }

        // FAVORITE
        if !metadata.lock {
            topMenuItems.append(makeFavoriteAction())
        }

        // VIEW IN FOLDER
        if !webView {
            menuElements.append(makeViewInFolderAction(metadata: metadata, controller: controller, viewController: viewController))
        }

        // OFFLINE
        if !webView, metadata.canSetAsAvailableOffline {
            menuElements.append(ContextMenuActions.setAvailableOffline(metadatas: [metadata], isAnyOffline: isOffline, controller: controller))
        }

        if !webView,
           metadata.isRenameable {
            //menuElements.append(ContextMenuActions.makeRenameAction(metadata: metadata))
        }

        // MOVE - COPY
        if !webView,
           metadata.isCopyableMovable {
            menuElements.append(ContextMenuActions.moveOrCopy(metadatas: [metadata], account: metadata.account, controller: controller))
        }

        // LIVE PHOTO
        if !webView,
           NCNetworking.shared.isOnline,
           let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            menuElements.append(makeSaveLivePhotoAction(metadataMOV: metadataMOV))
        }

        // PDF ACTIONS
        if metadata.isPDF {
            menuElements.append(contentsOf: makePDFActions())
        }

        // MODIFY
        if metadata.isImage,
           utilityFileSystem.fileSizeIfExists(metadata) {
            menuElements.append(makeModifyPhoto())
        }

        // DELETE
        if !webView, metadata.isDeletable {
            menuElements.append(UIMenu(options: .displayInline, children: [
                ContextMenuActions.delete(metadatas: [metadata], controller: controller)
            ]))
        }

        // Assemble final menu
        let topMenu = UIMenu(title: "", options: .displayInline, children: topMenuItems)
        topMenu.preferredElementSize = .medium // top menu items are shown in a short format style

        let baseMenu = UIMenu(title: "", options: .displayInline, children: menuElements)

        return UIMenu(title: "", children: [topMenu, baseMenu])
    }

    // MARK: - Private Action Makers

    private func makeDetailAction(metadata: tableMetadata, controller: NCMainTabBarController, presentViewController: UIViewController?) -> UIAction {
        UIAction(
            title: NSLocalizedString("_details_", comment: ""),
            image: UIImage(systemName: "info.circle.fill")
        ) { _ in
            NCCreate().createShare(controller: controller,
                                   presentViewController: presentViewController,
                                   metadata: metadata,
                                   page: .activity)
        }
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

    private func makeFavoriteAction() -> UIAction {
        UIAction(
            title: metadata.favorite
                ? NSLocalizedString("_remove_favorites_", comment: "")
                : NSLocalizedString("_add_favorites_", comment: ""),
            image: utility.loadImage(named: metadata.favorite ? "star.slash.fill" : "star.fill", colors: [NCBrandColor.shared.yellowFavorite])
        ) { _ in
            Task {
                await NCNetworking.shared.setStatusWaitFavorite(self.metadata)
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

    private func makeSaveLivePhotoAction(metadataMOV: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_livephoto_save_", comment: ""),
            image: utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            NCNetworking.shared.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: self.metadata, metadataMOV: metadataMOV, windowScene: self.windowScene))
        }
    }

    private func makeModifyPhoto() -> UIAction {
        return UIAction(
            title: NSLocalizedString("_modify_", comment: ""),
            image: utility.loadImage(named: "pencil.tip.crop.circle", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            Task {
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(
                        status: NCGlobal.shared.networkingStatusDownloaded,
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
