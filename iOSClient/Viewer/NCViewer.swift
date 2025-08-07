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

    @MainActor
    func getViewerController(metadata: tableMetadata, ocIds: [String]? = nil, image: UIImage? = nil, delegate: UIViewController? = nil) async -> UIViewController? {
        let session = NCSession.shared.getSession(account: metadata.account)
        let isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: metadata.serverUrl, urlBase: session.urlBase, userId: session.userId, account: session.account)

        // URL
        if metadata.classFile == NKTypeClassFile.url.rawValue,
           !isDirectoryE2EE {
            // nextcloudtalk://open-conversation?server={serverURL}&user={userId}&withRoomToken={roomToken}
            if metadata.name == NCGlobal.shared.talkName {
                let pathComponents = metadata.url.components(separatedBy: "/")
                if pathComponents.contains("call") {
                    let talkComponents = pathComponents.last?.components(separatedBy: "#")
                    if let roomToken = talkComponents?.first {
                        let urlString = "nextcloudtalk://open-conversation?server=\(session.urlBase)&user=\(session.userId)&withRoomToken=\(roomToken)"
                        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                            await UIApplication.shared.open(url)
                        }
                    }
                }
            } else if let url = URL(string: metadata.url) {
                await UIApplication.shared.open(url)
            }
            return nil
        }

        // IMAGE AUDIO VIDEO
        else if metadata.isImage || metadata.isAudioOrVideo {
            let viewerMediaPageContainer = UIStoryboard(name: "NCViewerMediaPage", bundle: nil).instantiateInitialViewController() as? NCViewerMediaPage

            viewerMediaPageContainer?.delegateViewController = delegate
            if let ocIds {
                viewerMediaPageContainer?.currentIndex = ocIds.firstIndex(where: { $0 == metadata.ocId }) ?? 0
                viewerMediaPageContainer?.ocIds = ocIds
            } else {
                viewerMediaPageContainer?.currentIndex = 0
                viewerMediaPageContainer?.ocIds = [metadata.ocId]
            }

            return viewerMediaPageContainer
        }

        // DOCUMENTS
        else if metadata.classFile == NKTypeClassFile.document.rawValue,
                !isDirectoryE2EE {
            // Set Last Opening Date
            await self.database.setLastOpeningDateAsync(metadata: metadata)

            // PDF
            if metadata.isPDF {
                let vc = UIStoryboard(name: "NCViewerPDF", bundle: nil).instantiateInitialViewController() as? NCViewerPDF

                vc?.metadata = metadata
                vc?.imageIcon = image
                vc?.navigationItem.title = metadata.fileNameView

                return vc
            }
            // RichDocument: Collabora
            if metadata.isAvailableRichDocumentEditorView {
                if metadata.url.isEmpty {

                    NCActivityIndicator.shared.start(backgroundView: delegate?.view)
                    let results = await NextcloudKit.shared.createUrlRichdocumentsAsync(fileID: metadata.fileId, account: metadata.account)
                    NCActivityIndicator.shared.stop()

                    guard results.error == .success, let url = results.url else {
                        NCContentPresenter().showError(error: results.error)
                        return nil
                    }

                    let vc = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as? NCViewerRichDocument

                    vc?.metadata = metadata
                    vc?.link = url
                    vc?.imageIcon = image
                    vc?.navigationItem.title = metadata.fileNameView

                    return vc

                } else {
                    let vc = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as? NCViewerRichDocument

                    vc?.metadata = metadata
                    vc?.link = metadata.url
                    vc?.imageIcon = image
                    vc?.navigationItem.title = metadata.fileNameView

                    return vc
                }
            }
            // DirectEditing: Nextcloud Text - OnlyOffice
            if metadata.isAvailableDirectEditingEditorView {
                var options = NKRequestOptions()
                var editor = ""
                var editorViewController = ""
                let editors = utility.editorsDirectEditing(account: metadata.account, contentType: metadata.contentType)
                if editors.contains("Nextcloud Text") {
                    editor = "text"
                    editorViewController = "Nextcloud Text"
                    options = NKRequestOptions(customUserAgent: utility.getCustomUserAgentNCText())
                } else if editors.contains("ONLYOFFICE") {
                    editor = "onlyoffice"
                    editorViewController = "onlyoffice"
                    options = NKRequestOptions(customUserAgent: utility.getCustomUserAgentOnlyOffice())
                }
                if metadata.url.isEmpty {
                    let fileNamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)

                    NCActivityIndicator.shared.start(backgroundView: delegate?.view)
                    let results = await NextcloudKit.shared.textOpenFileAsync(fileNamePath: fileNamePath, editor: editor, account: metadata.account, options: options)
                    NCActivityIndicator.shared.stop()

                    guard results.error == .success, let url = results.url else {
                        NCContentPresenter().showError(error: results.error)
                        return nil
                    }

                    let vc = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as? NCViewerNextcloudText

                    vc?.metadata = metadata
                    vc?.editor = editorViewController
                    vc?.link = url
                    vc?.imageIcon = image
                    vc?.navigationItem.title = metadata.fileNameView

                    return vc
                } else {
                    let vc = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as? NCViewerNextcloudText

                    vc?.metadata = metadata
                    vc?.editor = editorViewController
                    vc?.link = metadata.url
                    vc?.imageIcon = image
                    vc?.navigationItem.title = metadata.fileNameView

                    return vc
                }
            }
        }
        // QLPreview
        else {
            let item = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                              fileName: metadata.fileNameView,
                                                                                              userId: metadata.userId,
                                                                                              urlBase: metadata.urlBase))
            if QLPreviewController.canPreview(item as QLPreviewItem) {
                let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
                utilityFileSystem.copyFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                                     fileName: metadata.fileNameView,
                                                                                                     userId: metadata.userId,
                                                                                                     urlBase: metadata.urlBase), toPath: fileNamePath)
                let viewerQuickLook = NCViewerQuickLook(with: URL(fileURLWithPath: fileNamePath), isEditingEnabled: false, metadata: metadata)
                delegate?.present(viewerQuickLook, animated: true)
            } else {
                // Document Interaction Controller
                if let controller = delegate?.tabBarController as? NCMainTabBarController {
                    NCDownloadAction.shared.openActivityViewController(selectedMetadata: [metadata], controller: controller, sender: nil)
                }
            }
        }
        return nil
    }
}
