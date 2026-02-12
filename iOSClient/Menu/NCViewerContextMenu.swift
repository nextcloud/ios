// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

/// A context menu created to be used universally with the different `NCViewer`s.
/// See ``NCViewerImage``, ``NCViewerMedia``, ``NCViewerPDF`` for usage details.
class NCViewerContextMenu: NSObject {
    let metadata: tableMetadata
    let controller: NCMainTabBarController?
    let webView: Bool
    let sender: Any?
    private let database = NCManageDatabase.shared
    private let utility = NCUtility()

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
            menuElements.append(makeDetailAction(metadata: metadata))
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
            menuElements.append(ContextMenuActions.setAvailableOffline(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: controller))
        }

        // SHARE
        if !webView, metadata.canShare {
            menuElements.append(ContextMenuActions.share(selectedMetadatas: [metadata], controller: controller, sender: sender))
        }

        // PDF ACTIONS
        if metadata.isPDF {
            menuElements.append(contentsOf: makePDFActions())
        }

        // DELETE
        if !webView, metadata.isDeletable {
            menuElements.append(ContextMenuActions.deleteOrUnshare(selectedMetadatas: [metadata], controller: controller))
        }

        return UIMenu(title: "", children: menuElements)
    }

    // MARK: - Private Action Makers

    private func makeDetailAction(metadata: tableMetadata) -> UIAction {
        UIAction(
            title: NSLocalizedString("_details_", comment: ""),
            image: UIImage(systemName: "info")
        ) { [weak self] _ in
            guard let controller = self?.controller else { return }
            NCCreate().createShare(viewController: controller,
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
                await NCNetworking.shared.openFileViewInFolder(serverUrl: metadata.serverUrl,
                                                               fileNameBlink: metadata.fileName,
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
            NCNetworking.shared.setStatusWaitFavorite(metadata) { error in
                if error != .success {
                    Task {
                        await showErrorBanner(controller: controller, text: error.errorDescription, errorCode: error.errorCode)
                    }
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
}
