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

    func getViewerController(metadata: tableMetadata, ocIds: [String]? = nil, image: UIImage? = nil, delegate: UIViewController? = nil, completion: @escaping (UIViewController?) -> Void) {
        let session = NCSession.shared.getSession(account: metadata.account)

        // URL
        if metadata.classFile == NKTypeClassFile.url.rawValue {
            // nextcloudtalk://open-conversation?server={serverURL}&user={userId}&withRoomToken={roomToken}
            if metadata.name == NCGlobal.shared.talkName {
                let pathComponents = metadata.url.components(separatedBy: "/")
                if pathComponents.contains("call") {
                    let talkComponents = pathComponents.last?.components(separatedBy: "#")
                    if let roomToken = talkComponents?.first {
                        let urlString = "nextcloudtalk://open-conversation?server=\(session.urlBase)&user=\(session.userId)&withRoomToken=\(roomToken)"
                        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } else if let url = URL(string: metadata.url) {
                UIApplication.shared.open(url)
            }
            return completion(nil)
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

            return completion(viewerMediaPageContainer)
        }

        // DOCUMENTS
        else if metadata.classFile == NKTypeClassFile.document.rawValue {
            // Set Last Opening Date
            Task {
                await self.database.setLastOpeningDateAsync(metadata: metadata)
            }
            // PDF
            if metadata.isPDF {
                let viewController = UIStoryboard(name: "NCViewerPDF", bundle: nil).instantiateInitialViewController() as? NCViewerPDF

                viewController?.metadata = metadata
                viewController?.titleView = metadata.fileNameView
                viewController?.imageIcon = image

                return completion(viewController)
            }
            // RichDocument: Collabora
            if metadata.isAvailableRichDocumentEditorView {
                if metadata.url.isEmpty {
                    NCActivityIndicator.shared.start(backgroundView: delegate?.view)
                    NextcloudKit.shared.createUrlRichdocuments(fileID: metadata.fileId, account: metadata.account) { _, url, _, error in
                        NCActivityIndicator.shared.stop()
                        if error == .success, url != nil {
                            let viewController = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as? NCViewerRichDocument

                            viewController?.metadata = metadata
                            viewController?.link = url!
                            viewController?.imageIcon = image

                            return completion(viewController)

                        } else if error != .success {
                            NCContentPresenter().showError(error: error)
                        }
                        return completion(nil)
                    }
                } else {
                    let viewController = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as? NCViewerRichDocument

                    viewController?.metadata = metadata
                    viewController?.link = metadata.url
                    viewController?.imageIcon = image

                    return completion(viewController)
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
                    NextcloudKit.shared.textOpenFile(fileNamePath: fileNamePath, editor: editor, account: metadata.account, options: options) { _, url, _, error in
                        NCActivityIndicator.shared.stop()
                        if error == .success, url != nil {
                            let viewController = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as? NCViewerNextcloudText

                            viewController?.metadata = metadata
                            viewController?.editor = editorViewController
                            viewController?.link = url!
                            viewController?.imageIcon = image

                            return completion(viewController)

                        } else if error != .success {
                            NCContentPresenter().showError(error: error)
                        }
                        return completion(nil)
                    }
                } else {
                    let viewController = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as? NCViewerNextcloudText

                    viewController?.metadata = metadata
                    viewController?.editor = editorViewController
                    viewController?.link = metadata.url
                    viewController?.imageIcon = image

                    return completion(viewController)
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
            return completion(nil)
        }
    }
}
