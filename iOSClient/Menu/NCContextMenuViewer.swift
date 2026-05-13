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
    let webView: Bool
    let sender: Any?
    private let database = NCManageDatabase.shared
    private let utility = NCUtility()

    internal var windowScene: UIWindowScene? {
       SceneManager.shared.getWindowScene(controller: controller)
    }

    init(metadata: tableMetadata, controller: NCMainTabBarController?, webView: Bool, sender: Any?) {
        self.metadata = metadata
        self.controller = controller
        self.webView = webView
        self.sender = sender
    }

    func viewMenu() -> UIMenu? {
        guard let metadata = database.getMetadataFromOcId(metadata.ocId),
              let controller,
              let capabilities = NCNetworking.shared.capabilities[metadata.account] else {
            return nil
        }

        var menuElements: [UIMenuElement] = []
        let localFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        let isOffline = localFile?.offline == true

        // DETAIL
        if !(!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty) {
            menuElements.append(makeDetailAction(metadata: metadata, controller: controller))
        }

        // VIEW IN FOLDER
        if !webView {
            menuElements.append(makeViewInFolderAction(metadata: metadata, controller: controller))
        }

        // FAVORITE
        if !metadata.lock {
            menuElements.append(makeFavoriteAction(metadata: metadata, controller: controller))
        }

        // OFFLINE
        if !webView, metadata.canSetAsAvailableOffline {
            menuElements.append(ContextMenuActions.setAvailableOffline(metadatas: [metadata], isAnyOffline: isOffline, controller: controller))
        }

        // LIVE PHOTO
        if !webView,
           NCNetworking.shared.isOnline,
           let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            menuElements.append(makeSaveLivePhotoAction(metadata: metadata, metadataMOV: metadataMOV))
        }

        // SHARE
        if !webView, metadata.canShare {
            menuElements.append(ContextMenuActions.share(metadatas: [metadata], controller: controller, sender: sender))
        }

        // PDF ACTIONS
        if metadata.isPDF {
            menuElements.append(contentsOf: makePDFActions())
        }

        // DELETE
        if !webView, metadata.isDeletable {
            menuElements.append(ContextMenuActions.delete(metadatas: [metadata], controller: controller))
        }

        return UIMenu(title: "", children: menuElements)
    }

    // MARK: - Private Action Makers

    private func makeDetailAction(metadata: tableMetadata, controller: NCMainTabBarController) -> UIAction {
        UIAction(
            title: NSLocalizedString("_details_", comment: ""),
            image: UIImage(systemName: "info")
        ) { _ in
            NCCreate().createShare(controller: controller,
                                   metadata: metadata,
                                   page: .activity)
        }
    }

    private func makeViewInFolderAction(metadata: tableMetadata, controller: NCMainTabBarController) -> UIAction {
        UIAction(
            title: NSLocalizedString("_view_in_folder_", comment: ""),
            image: UIImage(systemName: "questionmark.folder")
        ) { _ in
            Task {
                await NCNetworking.shared.blinkInFolder(serverUrl: metadata.serverUrl,
                                                        fileName: metadata.fileName,
                                                        sceneIdentifier: controller.sceneIdentifier)
            }
        }
    }

    private func makeFavoriteAction(metadata: tableMetadata, controller: NCMainTabBarController) -> UIAction {
        UIAction(
            title: metadata.favorite
                ? NSLocalizedString("_remove_favorites_", comment: "")
                : NSLocalizedString("_add_favorites_", comment: ""),
            image: utility.loadImage(named: metadata.favorite ? "star.slash" : "star", colors: [NCBrandColor.shared.yellowFavorite])
        ) { _ in
            Task {
                await NCNetworking.shared.setStatusWaitFavorite(metadata)
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

    private func makeSaveLivePhotoAction(metadata: tableMetadata, metadataMOV: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_livephoto_save_", comment: ""),
            image: utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            NCNetworking.shared.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: metadata, metadataMOV: metadataMOV, windowScene: self.windowScene))
        }
    }
}
