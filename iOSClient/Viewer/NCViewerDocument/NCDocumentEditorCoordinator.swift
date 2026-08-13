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
    let selectedEditor: String?
    let delegate: UIViewController?

    init(metadata: tableMetadata, image: UIImage?, selectedEditor: String?, delegate: UIViewController?) {
        self.metadata = metadata
        self.image = image
        self.selectedEditor = selectedEditor
        self.delegate = delegate

        super.init()
    }

    func selectEditor() async -> UIViewController? {
        let availableEditors = Set(
            utility.editorsEditing(
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

        if selectedEditor == global.editorText {
            return await makeDirectEditingViewController(editor: global.editorText)
        } else if selectedEditor == global.editorEuroOffice {
            return await makeDirectEditingViewController(editor: global.editorEuroOffice)
        } else if selectedEditor == global.editorWhiteboard {
            return await makeDirectEditingViewController(editor: global.editorWhiteboard)
        } else if selectedEditor == global.editorCollabora {
            return await makeCollaboraViewController()
        } else if selectedEditor == global.editorOnlyOffice {
            return await makeDirectEditingViewController(editor: global.editorOnlyOffice)
        }

        return nil
    }

    // MARK: - Text editor

    private func makeDirectEditingViewController(editor: String) async -> UIViewController? {
        guard let editorAdapter = NCDirectEditorAdapter.resolve(from: [editor]) else {
            return nil
        }

        let account = metadata.account
        let editorIdentifier = selectedEditor ?? editorAdapter.apiKey
        let editorViewController = editorAdapter.viewControllerEditor
        let editorUserAgent = editorAdapter.userAgent(utility)
        let options = NKRequestOptions(customUserAgent: editorAdapter.userAgent(utility))
        let link: String

        if metadata.url.isEmpty {
            let session = NCSession.shared.getSession(account: account)
            let fileNamePath = utilityFileSystem.getRelativeFilePath(
                metadata.fileName,
                serverUrl: metadata.serverUrl,
                session: session
            )

            NCActivityIndicator.shared.start(backgroundView: delegate?.view)

            let results = await NextcloudKit.shared.textOpenFileAsync(
                fileNamePath: fileNamePath,
                editor: editorIdentifier,
                account: account,
                options: options
            ) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: account,
                        path: fileNamePath,
                        name: "textOpenFile"
                    )

                    await NCNetworking.shared.networkingTasks.track(
                        identifier: identifier,
                        task: task
                    )
                }
            }

            NCActivityIndicator.shared.stop()

            guard results.error == .success, let generatedURL = results.url else {
                let windowScene = SceneManager.shared.getWindowScene(controller: delegate?.tabBarController as? NCMainTabBarController)
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

        guard let viewController = UIStoryboard(
            name: "NCViewerDirectEditing",
            bundle: nil
        ).instantiateInitialViewController() as? NCViewerDirectEditing else {
            return nil
        }

        viewController.metadata = metadata
        viewController.editor = editorViewController
        viewController.link = link
        viewController.userAgent = editorUserAgent
        viewController.imageIcon = image
        viewController.navigationItem.setBidiSafeTitle(metadata.fileNameView)

        return viewController
    }

    // MARK: - Collabora

    private func makeCollaboraViewController() async -> UIViewController? {
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
                let windowScene = SceneManager.shared.getWindowScene(controller: delegate?.tabBarController as? NCMainTabBarController)
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
