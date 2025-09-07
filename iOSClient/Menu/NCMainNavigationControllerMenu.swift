// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

extension NCMainNavigationController {
    func plusMenu() -> UIMenu? {
        guard let controller else {
            return nil
        }
        let session = NCSession.shared.getSession(controller: controller)
        let utilityFileSystem = NCUtilityFileSystem()
        let serverUrl = controller.currentServerUrl()
        let isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, urlBase: session.urlBase, userId: session.userId, account: session.account)
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))
        let utility = NCUtility()
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
        var menuAction: [UIMenuElement] = []

        menuAction.append(UIAction(title: NSLocalizedString("_upload_photos_videos_", comment: ""),
                                                image: utility.loadImage(named: "photo", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
                if hasPermission {NCPhotosPickerViewController(controller: controller, maxSelectedAssets: 0, singleSelectedMode: false)
                }
            }
        })


        menuAction.append(UIAction(title: NSLocalizedString("_upload_file_", comment: ""),
                                        image: utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            controller.documentPickerViewController = NCDocumentPickerViewController(controller: controller, isViewerMedia: false, allowsMultipleSelection: true)
        })

        if NextcloudKit.shared.isNetworkReachable(),
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "text" }),
           !isDirectoryE2EE {

        }
        return UIMenu(title: "", options: .displayInline, children: menuAction)
    }
}
