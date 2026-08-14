// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class NCRichWorkspaceCoordinator: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared

    func createRichWorkspace(serverUrl: String, viewController: UIViewController, controller: NCMainTabBarController?, session: NCSession.Session) {
        if !NextcloudKit.shared.isNetworkReachable() {
            Task {
                let windowScene = await SceneManager.shared.getWindowScene(controller: controller)
                await showErrorBanner(windowScene: windowScene, text: "_go_online_", errorCode: NCGlobal.shared.errorOfflineNotAllowed)
            }
            return
        }

        guard let capabilities = NCNetworking.shared.capabilities[session.account],
              let textCreator = capabilities.directEditingCreators.first(where: { $0.editor == global.editorText }) else {
            return
        }

        NCActivityIndicator.shared.start(backgroundView: viewController.view)

        let fileNamePath = utilityFileSystem.getRelativeFilePath(NCGlobal.shared.fileNameRichWorkspace, serverUrl: serverUrl, session: session)
        NextcloudKit.shared.createFileForDirectEditing(fileNamePath: fileNamePath, editorId: textCreator.editor, creatorId: textCreator.identifier, templateId: "", account: session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                            path: fileNamePath,
                                                                                            name: "createFileForDirectEditing")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, url, _, error in
            NCActivityIndicator.shared.stop()
            guard error == .success, let url else {
                let resultError: NKError = error == .success ? .invalidData : error
                Task {
                    let windowScene = await SceneManager.shared.getWindowScene(controller: controller)
                    await showErrorBanner(windowScene: windowScene, text: resultError.errorDescription, errorCode: resultError.errorCode)
                }
                return
            }
            if let viewerRichWorkspaceWebView = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerRichWorkspaceWebView") as? NCViewerRichWorkspaceWebView {
                viewerRichWorkspaceWebView.url = url
                viewerRichWorkspaceWebView.controller = controller
                viewerRichWorkspaceWebView.presentationController?.delegate = viewController as? UIAdaptivePresentationControllerDelegate
                viewController.present(viewerRichWorkspaceWebView, animated: true, completion: nil)
            }
        }
    }

    func openRichWorkspace(serverUrl: String, viewController: UIViewController, controller: NCMainTabBarController?, session: NCSession.Session) {
        if !NextcloudKit.shared.isNetworkReachable() {
            Task {
                let windowScene = await SceneManager.shared.getWindowScene(controller: controller)
                await showErrorBanner(windowScene: windowScene, text: "_go_online_", errorCode: NCGlobal.shared.errorOfflineNotAllowed)
            }
            return
        }

        if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@",
                                                                                     session.account,
                                                                                     serverUrl,
                                                                                     NCGlobal.shared.fileNameRichWorkspace.lowercased())) {

            if metadata.url.isEmpty {
                NCActivityIndicator.shared.start(backgroundView: viewController.view)

                let fileNamePath = utilityFileSystem.getRelativeFilePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)
                NextcloudKit.shared.openFileForDirectEditing(fileNamePath: fileNamePath, fileId: metadata.fileId, editorId: global.editorText, account: metadata.account) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                                    path: fileNamePath,
                                                                                                    name: "openFileForDirectEditing")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                } completion: { _, url, _, error in
                    NCActivityIndicator.shared.stop()
                    guard error == .success, let url else {
                        let resultError: NKError = error == .success ? .invalidData : error
                        Task {
                            let windowScene = await SceneManager.shared.getWindowScene(controller: controller)
                            await showErrorBanner(windowScene: windowScene, text: resultError.errorDescription, errorCode: resultError.errorCode)
                        }
                        return
                    }
                    if let viewerRichWorkspaceWebView = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerRichWorkspaceWebView") as? NCViewerRichWorkspaceWebView {
                        viewerRichWorkspaceWebView.url = url
                        viewerRichWorkspaceWebView.controller = controller
                        viewerRichWorkspaceWebView.metadata = metadata
                        viewerRichWorkspaceWebView.presentationController?.delegate = viewController as? UIAdaptivePresentationControllerDelegate
                        viewController.present(viewerRichWorkspaceWebView, animated: true, completion: nil)
                    }
                }
            } else {
                if let viewerRichWorkspaceWebView = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerRichWorkspaceWebView") as? NCViewerRichWorkspaceWebView {
                    viewerRichWorkspaceWebView.url = metadata.url
                    viewerRichWorkspaceWebView.controller = controller
                    viewerRichWorkspaceWebView.metadata = metadata
                    viewerRichWorkspaceWebView.presentationController?.delegate = viewController as? UIAdaptivePresentationControllerDelegate
                    viewController.present(viewerRichWorkspaceWebView, animated: true, completion: nil)
                }
            }
        }
    }
}
