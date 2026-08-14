// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

@MainActor
final class NCDocumentEditorCoordinator {
    private enum EditorRoute {
        case directEditing(editorId: String)
        case legacyRichdocuments
    }

    private let utilityFileSystem = NCUtilityFileSystem()
    private let global = NCGlobal.shared

    private let metadata: tableMetadata
    private let image: UIImage?
    private let selectedEditor: String?
    private let delegate: UIViewController?

    private var automaticEditorOrder: [String] {
        [
            global.editorText,
            global.editorEuroOffice,
            global.editorCollabora,
            global.editorOnlyOffice,
            global.editorWhiteboard
        ]
    }

    init(metadata: tableMetadata, image: UIImage?, selectedEditor: String?, delegate: UIViewController?) {
        self.metadata = metadata
        self.image = image
        self.selectedEditor = selectedEditor
        self.delegate = delegate
    }

    func selectEditor() async -> UIViewController? {
        guard let route = resolveEditorRoute() else {
            return nil
        }

        switch route {
        case .directEditing(let editorId):
            return await makeDirectEditingViewController(editorId: editorId)
        case .legacyRichdocuments:
            return await makeLegacyRichdocumentsViewController()
        }
    }

    private func resolveEditorRoute() -> EditorRoute? {
        let directEditingEditors = Set(
            NCDocumentEditorSupport.directEditingEditorIdentifiers(
                account: metadata.account,
                contentType: metadata.contentType
            )
            .map { $0.lowercased() }
        )
        let supportsLegacyRichdocuments = metadata.isLegacyRichdocumentsEditorAvailable

        if let selectedEditor = selectedEditor?.lowercased() {
            if directEditingEditors.contains(selectedEditor) {
                return .directEditing(editorId: selectedEditor)
            }
            if selectedEditor == global.editorCollabora,
               supportsLegacyRichdocuments {
                return .legacyRichdocuments
            }
            return nil
        }

        for editorId in automaticEditorOrder.map({ $0.lowercased() }) {
            if directEditingEditors.contains(editorId) {
                return .directEditing(editorId: editorId)
            }
            if editorId == global.editorCollabora,
               supportsLegacyRichdocuments {
                return .legacyRichdocuments
            }
        }

        return nil
    }

    private func makeDirectEditingViewController(editorId: String) async -> UIViewController? {
        guard let editorAdapter = NCDirectEditorAdapter.resolve(from: [editorId]) else {
            return nil
        }

        let editorUserAgent = editorAdapter.userAgent()
        let options = NKRequestOptions(customUserAgent: editorUserAgent)
        guard let link = await directEditingURL(editorId: editorAdapter.apiKey, options: options) else {
            return nil
        }

        let storyboard = UIStoryboard(name: "NCViewerDirectEditing", bundle: nil)
        guard let viewController = storyboard.instantiateInitialViewController(
            creator: { coder in
                NCViewerDirectEditing(
                    coder: coder,
                    link: link,
                    editor: editorAdapter.viewControllerEditor,
                    userAgent: editorUserAgent,
                    metadata: self.metadata,
                    imageIcon: self.image
                )
            }
        ) else {
            return nil
        }

        viewController.navigationItem.setBidiSafeTitle(metadata.fileNameView)
        return viewController
    }

    private func directEditingURL(editorId: String, options: NKRequestOptions) async -> String? {
        if !metadata.url.isEmpty {
            return metadata.url
        }

        let session = NCSession.shared.getSession(account: metadata.account)
        let fileNamePath = utilityFileSystem.getRelativeFilePath(
            metadata.fileName,
            serverUrl: metadata.serverUrl,
            session: session
        )
        let fileId = metadata.fileId.isEmpty ? nil : metadata.fileId

        NCActivityIndicator.shared.start(backgroundView: delegate?.view)
        defer { NCActivityIndicator.shared.stop() }

        let results = await NextcloudKit.shared.openFileForDirectEditingAsync(
            fileNamePath: fileNamePath,
            fileId: fileId,
            editorId: editorId,
            account: metadata.account,
            options: options
        ) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: self.metadata.account,
                    path: fileNamePath,
                    name: "openFileForDirectEditing"
                )
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        guard results.error == .success,
              let generatedURL = results.url,
              !generatedURL.isEmpty else {
            await showEditorError(results.error == .success ? .invalidData : results.error)
            return nil
        }

        return generatedURL
    }

    private func makeLegacyRichdocumentsViewController() async -> UIViewController? {
        guard let link = await legacyRichdocumentsURL() else {
            return nil
        }

        guard let viewController = UIStoryboard(
            name: "NCViewerRichdocuments",
            bundle: nil
        ).instantiateInitialViewController() as? NCViewerRichdocuments else {
            return nil
        }

        viewController.metadata = metadata
        viewController.link = link
        viewController.imageIcon = image
        viewController.navigationItem.setBidiSafeTitle(metadata.fileNameView)
        return viewController
    }

    private func legacyRichdocumentsURL() async -> String? {
        if !metadata.url.isEmpty {
            return metadata.url
        }

        guard !metadata.fileId.isEmpty else {
            await showEditorError(.invalidData)
            return nil
        }

        NCActivityIndicator.shared.start(backgroundView: delegate?.view)
        defer { NCActivityIndicator.shared.stop() }

        let results = await NextcloudKit.shared.createRichdocumentsEditorURLAsync(
            fileId: metadata.fileId,
            account: metadata.account
        ) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: self.metadata.account,
                    path: self.metadata.fileId,
                    name: "createRichdocumentsEditorURL"
                )
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        guard results.error == .success,
              let generatedURL = results.url,
              !generatedURL.isEmpty else {
            await showEditorError(results.error == .success ? .invalidData : results.error)
            return nil
        }

        return generatedURL
    }

    private func showEditorError(_ error: NKError) async {
        let windowScene = SceneManager.shared.getWindowScene(
            controller: delegate?.tabBarController as? NCMainTabBarController
        )
        await showErrorBanner(
            windowScene: windowScene,
            text: error.errorDescription,
            errorCode: error.errorCode
        )
    }
}
