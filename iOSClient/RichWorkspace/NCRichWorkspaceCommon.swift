//
//  NCRichWorkspaceCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/01/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

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
        guard let directEditingCreator = NCManageDatabase.shared.getDirectEditingCreators(predicate: NSPredicate(format: "account == %@ AND editor == 'text'", session.account))?.first else { return }

        NCActivityIndicator.shared.start(backgroundView: viewController.view)

        let fileNamePath = utilityFileSystem.getFileNamePath(NCGlobal.shared.fileNameRichWorkspace, serverUrl: serverUrl, session: session)
        NextcloudKit.shared.NCTextCreateFile(fileNamePath: fileNamePath, editorId: directEditingCreator.editor, creatorId: directEditingCreator.identifier, templateId: "", account: session.account) { _, url, _, error in
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
                NextcloudKit.shared.NCTextOpenFile(fileNamePath: fileNamePath, editor: "text", account: metadata.account) { _, url, _, error in
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
