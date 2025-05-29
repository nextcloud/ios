//
//  NCViewer.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/10/2020.
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
import QuickLook

class NCViewer: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    private var viewerQuickLook: NCViewerQuickLook?

    func view(viewController: UIViewController, metadata: tableMetadata, ocIds: [String]? = nil, image: UIImage? = nil) {
        let session = NCSession.shared.getSession(account: metadata.account)

        // URL
        if metadata.classFile == NKCommon.TypeClassFile.url.rawValue {
            // nextcloudtalk://open-conversation?server={serverURL}&user={userId}&withRoomToken={roomToken}
            if metadata.name == NCGlobal.shared.talkName {
                let pathComponents = metadata.url.components(separatedBy: "/")
                if pathComponents.contains("call") {
                    let talkComponents = pathComponents.last?.components(separatedBy: "#")
                    if let roomToken = talkComponents?.first {
                        let urlString = "nextcloudtalk://open-conversation?server=\(session.urlBase)&user=\(session.userId)&withRoomToken=\(roomToken)"
                        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                            return
                        }
                    }
                }
            }
            if let url = URL(string: metadata.url) {
                UIApplication.shared.open(url)
            }
            return
        }

        // IMAGE AUDIO VIDEO
        if metadata.isImage || metadata.isAudioOrVideo {
            if let navigationController = viewController.navigationController,
               let viewerMediaPageContainer: NCViewerMediaPage = UIStoryboard(name: "NCViewerMediaPage", bundle: nil).instantiateInitialViewController() as? NCViewerMediaPage {

                viewerMediaPageContainer.delegateViewController = viewController

                if let ocIds {
                    viewerMediaPageContainer.currentIndex = ocIds.firstIndex(where: { $0 == metadata.ocId }) ?? 0
                    viewerMediaPageContainer.ocIds = ocIds
                } else {
                    viewerMediaPageContainer.currentIndex = 0
                    viewerMediaPageContainer.ocIds = [metadata.ocId]
                }

                navigationController.pushViewController(viewerMediaPageContainer, animated: true)
            }
            return
        }

        // DOCUMENTS
        if metadata.classFile == NKCommon.TypeClassFile.document.rawValue {
            // Set Last Opening Date
            self.database.setLastOpeningDate(metadata: metadata)
            // PDF
            if metadata.isPDF {
                if let navigationController = viewController.navigationController,
                   let viewController: NCViewerPDF = UIStoryboard(name: "NCViewerPDF", bundle: nil).instantiateInitialViewController() as? NCViewerPDF {
                    viewController.metadata = metadata
                    viewController.titleView = metadata.fileNameView
                    viewController.imageIcon = image
                    navigationController.pushViewController(viewController, animated: true)
                }
                return
            }
            // RichDocument: Collabora
            if metadata.isAvailableRichDocumentEditorView {
                if metadata.url.isEmpty {
                    NCActivityIndicator.shared.start(backgroundView: viewController.view)
                    NextcloudKit.shared.createUrlRichdocuments(fileID: metadata.fileId, account: metadata.account) { _, url, _, error in
                        NCActivityIndicator.shared.stop()
                        if error == .success, url != nil {
                            if let navigationController = viewController.navigationController,
                               let viewController: NCViewerRichDocument = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as? NCViewerRichDocument {
                                viewController.metadata = metadata
                                viewController.link = url!
                                viewController.imageIcon = image
                                navigationController.pushViewController(viewController, animated: true)
                            }
                        } else if error != .success {
                            NCContentPresenter().showError(error: error)
                        }
                    }
                } else {
                    if let navigationController = viewController.navigationController,
                       let viewController: NCViewerRichDocument = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as? NCViewerRichDocument {
                        viewController.metadata = metadata
                        viewController.link = metadata.url
                        viewController.imageIcon = image
                        navigationController.pushViewController(viewController, animated: true)
                    }
                }
                return
            }
            // DirectEditing: Nextcloud Text - OnlyOffice
            if metadata.isAvailableDirectEditingEditorView {
                var options = NKRequestOptions()
                var editor = ""
                let editors = utility.editorsDirectEditing(account: metadata.account, contentType: metadata.contentType)
                if editors.contains(NCGlobal.shared.editorText) {
                    editor = NCGlobal.shared.editorText
                    options = NKRequestOptions(customUserAgent: utility.getCustomUserAgentNCText())
                } else if editors.contains(NCGlobal.shared.editorOnlyoffice) {
                    editor = NCGlobal.shared.editorOnlyoffice
                    options = NKRequestOptions(customUserAgent: utility.getCustomUserAgentOnlyOffice())
                }
                if metadata.url.isEmpty {
                    let fileNamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)
                    NCActivityIndicator.shared.start(backgroundView: viewController.view)
                    NextcloudKit.shared.textOpenFile(fileNamePath: fileNamePath, editor: editor, account: metadata.account, options: options) { _, url, _, error in
                        NCActivityIndicator.shared.stop()
                        if error == .success, url != nil {
                            if let navigationController = viewController.navigationController,
                               let viewController: NCViewerNextcloudText = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as? NCViewerNextcloudText {
                                viewController.metadata = metadata
                                viewController.editor = editor
                                viewController.link = url!
                                viewController.imageIcon = image
                                navigationController.pushViewController(viewController, animated: true)
                            }
                        } else if error != .success {
                            NCContentPresenter().showError(error: error)
                        }
                    }
                } else {
                    if let navigationController = viewController.navigationController,
                       let viewController: NCViewerNextcloudText = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as? NCViewerNextcloudText {
                        viewController.metadata = metadata
                        viewController.editor = editor
                        viewController.link = metadata.url
                        viewController.imageIcon = image
                        navigationController.pushViewController(viewController, animated: true)
                    }
                }
                return
            }
        }

        // QLPreview
        let item = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
        if QLPreviewController.canPreview(item as QLPreviewItem) {
            let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
            utilityFileSystem.copyFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: fileNamePath)
            let viewerQuickLook = NCViewerQuickLook(with: URL(fileURLWithPath: fileNamePath), isEditingEnabled: false, metadata: metadata)
            viewController.present(viewerQuickLook, animated: true)
        } else {
            // Document Interaction Controller
            if let controller = viewController.tabBarController as? NCMainTabBarController {
                NCDownloadAction.shared.openActivityViewController(selectedMetadata: [metadata], controller: controller, sender: nil)
            }
        }
    }
}
