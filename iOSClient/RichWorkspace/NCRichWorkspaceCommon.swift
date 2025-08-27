// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class NCRichWorkspaceCommon: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()

    func createViewerNextcloudText(serverUrl: String, viewController: UIViewController, session: NCSession.Session) {
        if !NextcloudKit.shared.isNetworkReachable() {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_go_online_")
            NCContentPresenter().showError(error: error)
            return
        }

        guard let capabilities = NCNetworking.shared.capabilities[session.account],
              let textCreators = capabilities.directEditingCreators.filter({ $0.editor == "text" }).first else {
            return
        }

        NCActivityIndicator.shared.start(backgroundView: viewController.view)

        let fileNamePath = utilityFileSystem.getFileNamePath(NCGlobal.shared.fileNameRichWorkspace, serverUrl: serverUrl, session: session)
        NextcloudKit.shared.textCreateFile(fileNamePath: fileNamePath, editorId: textCreators.editor, creatorId: textCreators.identifier, templateId: "", account: session.account) { task in
            Task {
                let identifier = session.account + fileNamePath + NCGlobal.shared.taskIdentifierTextCreateFile
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, url, _, error in
            NCActivityIndicator.shared.stop()
            if error == .success {
                if let viewerRichWorkspaceWebView = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerRichWorkspaceWebView") as? NCViewerRichWorkspaceWebView {
                    viewerRichWorkspaceWebView.url = url!
                    viewerRichWorkspaceWebView.presentationController?.delegate = viewController as? UIAdaptivePresentationControllerDelegate
                    viewController.present(viewerRichWorkspaceWebView, animated: true, completion: nil)
                }
            } else if error != .success {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    func openViewerNextcloudText(serverUrl: String, viewController: UIViewController, session: NCSession.Session) {
        if !NextcloudKit.shared.isNetworkReachable() {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_go_online_")
            return NCContentPresenter().showError(error: error)
        }

        if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@",
                                                                                     session.account,
                                                                                     serverUrl,
                                                                                     NCGlobal.shared.fileNameRichWorkspace.lowercased())) {

            if metadata.url.isEmpty {
                NCActivityIndicator.shared.start(backgroundView: viewController.view)

                let fileNamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)
                NextcloudKit.shared.textOpenFile(fileNamePath: fileNamePath, editor: "text", account: metadata.account) { task in
                    Task {
                        let identifier = metadata.account + fileNamePath + NCGlobal.shared.taskIdentifierTextOpenFile
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                } completion: { _, url, _, error in
                    NCActivityIndicator.shared.stop()
                    if error == .success {
                        if let viewerRichWorkspaceWebView = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerRichWorkspaceWebView") as? NCViewerRichWorkspaceWebView {
                            viewerRichWorkspaceWebView.url = url!
                            viewerRichWorkspaceWebView.metadata = metadata
                            viewerRichWorkspaceWebView.presentationController?.delegate = viewController as? UIAdaptivePresentationControllerDelegate
                            viewController.present(viewerRichWorkspaceWebView, animated: true, completion: nil)
                        }
                    } else if error != .success {
                        NCContentPresenter().showError(error: error)
                    }
                }
            } else {
                if let viewerRichWorkspaceWebView = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerRichWorkspaceWebView") as? NCViewerRichWorkspaceWebView {
                    viewerRichWorkspaceWebView.url = metadata.url
                    viewerRichWorkspaceWebView.metadata = metadata
                    viewerRichWorkspaceWebView.presentationController?.delegate = viewController as? UIAdaptivePresentationControllerDelegate
                    viewController.present(viewerRichWorkspaceWebView, animated: true, completion: nil)
                }
            }
        }
    }
}
