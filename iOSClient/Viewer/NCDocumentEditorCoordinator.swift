// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import QuickLook
import SwiftUI

@MainActor
final class NCDocumentEditorCoordinator: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    private var viewerQuickLook: NCViewerQuickLook?

    let metadata: tableMetadata
    let image: UIImage?
    let delegate: UIViewController?

    init(metadata: tableMetadata, image: UIImage?, delegate: UIViewController?) {
        self.metadata = metadata
        self.image = image
        self.delegate = delegate

        super.init()
    }

    func selectOffice() async -> UIViewController? {
        let availableEditors = Set(
            utility.editorsDirectEditing(
                account: metadata.account,
                contentType: metadata.contentType
            )
            .map { $0.lowercased() }
        )

        guard let selectedEditor = global.priorityEditors
            .lazy
            .map({ $0.lowercased() })
            .first(where: availableEditors.contains) else {
            return nil
        }

        if selectedEditor == global.editorText.lowercased() {
            // return await editorText()
            return nil
        } else if selectedEditor == global.editorEuroOffice.lowercased() {
            // return await editorEuroOffice()
            return nil
        } else if selectedEditor == global.editorCollabora.lowercased() {
            return await editorCollabora()
        }

        return nil
    }

    // COLLABORA
    //
    private func editorCollabora() async -> UIViewController? {
        let link: String

        if metadata.url.isEmpty {
            NCActivityIndicator.shared.start(backgroundView: delegate?.view)

            let results = await NextcloudKit.shared.createUrlRichdocumentsAsync(fileID: metadata.fileId, account: metadata.account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: self.metadata.account,
                        path: self.metadata.fileId,
                        name: "createUrlRichdocuments"
                    )

                    await NCNetworking.shared.networkingTasks.track(
                        identifier: identifier,
                        task: task
                    )
                }
            }

            NCActivityIndicator.shared.stop()

            guard results.error == .success, let generatedURL = results.url else {
                let windowScene = SceneManager.shared.getWindowScene(
                    controller: delegate?.tabBarController as? NCMainTabBarController
                )

                await showErrorBanner(
                    windowScene: windowScene,
                    text: results.error.errorDescription,
                    errorCode: results.error.errorCode
                )

                return nil
            }

            link = generatedURL
        } else {
            link = metadata.url
        }

        guard let viewController = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as? NCViewerRichDocument else {
            return nil
        }

        viewController.metadata = metadata
        viewController.link = link
        viewController.imageIcon = image
        viewController.navigationItem.setBidiSafeTitle(metadata.fileNameView)

        return viewController
    }
}
