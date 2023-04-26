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
    @objc static let shared: NCViewer = {
        let instance = NCViewer()
        return instance
    }()

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var viewerQuickLook: NCViewerQuickLook?
    private var metadata = tableMetadata()
    private var metadatas: [tableMetadata] = []

    func view(viewController: UIViewController, metadata: tableMetadata, metadatas: [tableMetadata], imageIcon: UIImage?, editor: String = "", isRichDocument: Bool = false) {

        self.metadata = metadata
        self.metadatas = metadatas

        var editor = editor
        var xxxxxxx = NextcloudKit.shared.nkCommonInstance.getInternalTypeIdentifier(typeIdentifier: metadata.contentType)

        // URL
        if metadata.classFile == NKCommon.TypeClassFile.url.rawValue {

            // nextcloudtalk://open-conversation?server={serverURL}&user={userId}&withRoomToken={roomToken}
            if metadata.name == NCGlobal.shared.talkName {
                let pathComponents = metadata.url.components(separatedBy: "/")
                if pathComponents.contains("call") {
                    let talkComponents = pathComponents.last?.components(separatedBy: "#")
                    if let roomToken = talkComponents?.first {
                        let urlString = "nextcloudtalk://open-conversation?server=\(appDelegate.urlBase)&user=\(appDelegate.userId)&withRoomToken=\(roomToken)"
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
        if metadata.classFile == NKCommon.TypeClassFile.image.rawValue || metadata.classFile == NKCommon.TypeClassFile.audio.rawValue || metadata.classFile == NKCommon.TypeClassFile.video.rawValue {

            if let navigationController = viewController.navigationController {

                let viewerMediaPageContainer: NCViewerMediaPage = UIStoryboard(name: "NCViewerMediaPage", bundle: nil).instantiateInitialViewController() as! NCViewerMediaPage
                var index = 0
                for medatasImage in metadatas {
                    if medatasImage.ocId == metadata.ocId {
                        viewerMediaPageContainer.currentIndex = index
                        break
                    }
                    index += 1
                }
                viewerMediaPageContainer.metadatas = metadatas
                navigationController.pushViewController(viewerMediaPageContainer, animated: true)
            }

            return
        }

        // DOCUMENTS
        if metadata.classFile == NKCommon.TypeClassFile.document.rawValue {

            // PDF
            if metadata.contentType == "application/pdf" || metadata.contentType == "com.adobe.pdf" {

                if let navigationController = viewController.navigationController {

                    let viewController: NCViewerPDF = UIStoryboard(name: "NCViewerPDF", bundle: nil).instantiateInitialViewController() as! NCViewerPDF

                    viewController.metadata = metadata
                    viewController.imageIcon = imageIcon

                    navigationController.pushViewController(viewController, animated: true)
                }
                return
            }

            // EDITORS
            let editors = NCUtility.shared.isDirectEditing(account: metadata.account, contentType: metadata.contentType)
            let availableRichDocument = NCUtility.shared.isRichDocument(metadata)

            // RichDocument: Collabora
            if (isRichDocument || (availableRichDocument && editors.count == 0)) && NextcloudKit.shared.isNetworkReachable() {

                if metadata.url == "" {

                    NCActivityIndicator.shared.start(backgroundView: viewController.view)
                    NextcloudKit.shared.createUrlRichdocuments(fileID: metadata.fileId) { account, url, data, error in

                        NCActivityIndicator.shared.stop()

                        if error == .success && account == self.appDelegate.account && url != nil {

                            if let navigationController = viewController.navigationController {

                                let viewController: NCViewerRichdocument = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as! NCViewerRichdocument

                                viewController.metadata = metadata
                                viewController.link = url!
                                viewController.imageIcon = imageIcon

                                navigationController.pushViewController(viewController, animated: true)
                            }

                        } else if error != .success {

                            NCContentPresenter.shared.showError(error: error)
                        }
                    }

                } else {

                    if let navigationController = viewController.navigationController {

                        let viewController: NCViewerRichdocument = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as! NCViewerRichdocument

                        viewController.metadata = metadata
                        viewController.link = metadata.url
                        viewController.imageIcon = imageIcon

                        navigationController.pushViewController(viewController, animated: true)
                    }
                }

                return
            }

            // DirectEditing: Nextcloud Text - OnlyOffice
            if editors.count > 0 && NextcloudKit.shared.isNetworkReachable() {

                if editor == "" {
                    if editors.contains(NCGlobal.shared.editorText) {
                        editor = NCGlobal.shared.editorText
                    } else if editors.contains(NCGlobal.shared.editorOnlyoffice) {
                        editor = NCGlobal.shared.editorOnlyoffice
                    }
                }

                if editor == NCGlobal.shared.editorText || editor == NCGlobal.shared.editorOnlyoffice {

                    if metadata.url == "" {

                        let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)!

                        var options = NKRequestOptions()
                        if editor == NCGlobal.shared.editorOnlyoffice {
                            options = NKRequestOptions(customUserAgent: NCUtility.shared.getCustomUserAgentOnlyOffice())
                        } else {
                            options = NKRequestOptions(customUserAgent: NCUtility.shared.getCustomUserAgentNCText())
                        }

                        NCActivityIndicator.shared.start(backgroundView: viewController.view)
                        NextcloudKit.shared.NCTextOpenFile(fileNamePath: fileNamePath, editor: editor, options: options) { account, url, data, error in

                            NCActivityIndicator.shared.stop()

                            if error == .success && account == self.appDelegate.account && url != nil {

                                if let navigationController = viewController.navigationController {

                                    let viewController: NCViewerNextcloudText = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as! NCViewerNextcloudText

                                    viewController.metadata = metadata
                                    viewController.editor = editor
                                    viewController.link = url!
                                    viewController.imageIcon = imageIcon

                                    navigationController.pushViewController(viewController, animated: true)
                                }

                            } else if error != .success {

                                NCContentPresenter.shared.showError(error: error)
                            }
                        }

                    } else {

                        if let navigationController = viewController.navigationController {

                            let viewController: NCViewerNextcloudText = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as! NCViewerNextcloudText

                            viewController.metadata = metadata
                            viewController.editor = editor
                            viewController.link = metadata.url
                            viewController.imageIcon = imageIcon

                            navigationController.pushViewController(viewController, animated: true)
                        }
                    }

                } else {
                    let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_editor_unknown_")
                    NCContentPresenter.shared.showError(error: error)
                }

                return
            }
        }

        // QLPreview
        let item = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
        if QLPreviewController.canPreview(item as QLPreviewItem) {
            let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
            CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: fileNamePath)
            let viewerQuickLook = NCViewerQuickLook(with: URL(fileURLWithPath: fileNamePath), isEditingEnabled: false, metadata: metadata)
            viewController.present(viewerQuickLook, animated: true)
        } else {
        // Document Interaction Controller
            NCActionCenter.shared.openDocumentController(metadata: metadata)
        }
    }
}

// MARK: - SELECT

extension NCViewer: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {
        if let serverUrl = serverUrl {
            let metadata = items[0] as! tableMetadata
            if move {
                NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite) { error in
                    if error != .success {

                        NCContentPresenter.shared.showError(error: error)
                    }
                }
            } else if copy {
                NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite) { error in
                    if error != .success {

                        NCContentPresenter.shared.showError(error: error)
                    }
                }
            }
        }
    }
}
