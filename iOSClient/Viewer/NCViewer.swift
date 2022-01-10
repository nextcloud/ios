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
import NCCommunication

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
        var xxxxxxx = NCCommunicationCommon.shared.getInternalTypeIdentifier(typeIdentifier: metadata.contentType)

        // IMAGE AUDIO VIDEO
        if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {

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
        if metadata.classFile == NCCommunicationCommon.typeClassFile.document.rawValue {

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
            if (isRichDocument || (availableRichDocument && editors.count == 0)) && NCCommunication.shared.isNetworkReachable() {

                if metadata.url == "" {

                    NCUtility.shared.startActivityIndicator(backgroundView: viewController.view, blurEffect: true)
                    NCCommunication.shared.createUrlRichdocuments(fileID: metadata.fileId) { account, url, errorCode, errorDescription in

                        NCUtility.shared.stopActivityIndicator()

                        if errorCode == 0 && account == self.appDelegate.account && url != nil {

                            if let navigationController = viewController.navigationController {

                                let viewController: NCViewerRichdocument = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as! NCViewerRichdocument

                                viewController.metadata = metadata
                                viewController.link = url!
                                viewController.imageIcon = imageIcon

                                navigationController.pushViewController(viewController, animated: true)
                            }

                        } else if errorCode != 0 {

                            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
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
            if editors.count > 0 && NCCommunication.shared.isNetworkReachable() {

                if editor == "" {
                    if editors.contains(NCGlobal.shared.editorText) {
                        editor = NCGlobal.shared.editorText
                    } else if editors.contains(NCGlobal.shared.editorOnlyoffice) {
                        editor = NCGlobal.shared.editorOnlyoffice
                    }
                }

                if editor == NCGlobal.shared.editorText || editor == NCGlobal.shared.editorOnlyoffice {

                    if metadata.url == "" {

                        var customUserAgent: String?
                        let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!

                        if editor == NCGlobal.shared.editorOnlyoffice {
                            customUserAgent = NCUtility.shared.getCustomUserAgentOnlyOffice()
                        }

                        NCUtility.shared.startActivityIndicator(backgroundView: viewController.view, blurEffect: true)
                        NCCommunication.shared.NCTextOpenFile(fileNamePath: fileNamePath, editor: editor, customUserAgent: customUserAgent) { account, url, errorCode, errorMessage in

                            NCUtility.shared.stopActivityIndicator()

                            if errorCode == 0 && account == self.appDelegate.account && url != nil {

                                if let navigationController = viewController.navigationController {

                                    let viewController: NCViewerNextcloudText = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as! NCViewerNextcloudText

                                    viewController.metadata = metadata
                                    viewController.editor = editor
                                    viewController.link = url!
                                    viewController.imageIcon = imageIcon

                                    navigationController.pushViewController(viewController, animated: true)
                                }

                            } else if errorCode != 0 {

                                NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
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

                    NCContentPresenter.shared.messageNotification("_error_", description: "_editor_unknown_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
                }

                return
            }
        }

        // OTHER
        let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView

        CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: fileNamePath)

        let viewerQuickLook = NCViewerQuickLook(with: URL(fileURLWithPath: fileNamePath), editingMode: false, metadata: metadata)
        let navigationController = UINavigationController(rootViewController: viewerQuickLook)
        navigationController.modalPresentationStyle = .overFullScreen

        viewController.present(navigationController, animated: true)
    }
}

// MARK: - SELECT

extension NCViewer: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {
        if let serverUrl = serverUrl {
            let metadata = items[0] as! tableMetadata
            if move {
                NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite) { errorCode, errorDescription in
                    if errorCode != 0 {

                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                }
            } else if copy {
                NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite) { errorCode, errorDescription in
                    if errorCode != 0 {

                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                }
            }
        }
    }
}
