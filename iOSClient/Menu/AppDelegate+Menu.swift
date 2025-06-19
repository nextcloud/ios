//
//  AppDelegate+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//
//  Author Philippe Weidmann <philippe.weidmann@infomaniak.com>
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
import FloatingPanel
import NextcloudKit

extension AppDelegate {
    func toggleMenu(controller: NCMainTabBarController, sender: Any?) {
        var actions: [NCMenuAction] = []
        let session = NCSession.shared.getSession(controller: controller)
        let serverUrl = controller.currentServerUrl()
        let isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, account: session.account)
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))
        let utility = NCUtility()
        let capabilities = NKCapabilities.shared.getCapabilitiesBlocking(for: session.account)

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_photos_videos_", comment: ""),
                icon: utility.loadImage(named: "photo", colors: [NCBrandColor.shared.iconImageColor]),
                sender: sender,
                action: { _ in
                    NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
                        if hasPermission {NCPhotosPickerViewController(controller: controller, maxSelectedAssets: 0, singleSelectedMode: false)
                        }
                    }
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_file_", comment: ""),
                icon: utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor]),
                sender: sender,
                action: { _ in
                    controller.documentPickerViewController = NCDocumentPickerViewController(controller: controller, isViewerMedia: false, allowsMultipleSelection: true)
                }
            )
        )

        if NextcloudKit.shared.isNetworkReachable(),
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "text" }),
           !isDirectoryE2EE {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""),
                             icon: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.iconImageColor]),
                             sender: sender,
                             action: { _ in
                                 Task {
                                     let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + ".md", account: session.account, serverUrl: serverUrl)
                                     let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                                     NCCreateDocument().createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "text", creatorId: creator.identifier, templateId: "document", account: session.account)
                                 }
                })
            )
        }

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_scans_document_", comment: ""),
                icon: utility.loadImage(named: "doc.text.viewfinder", colors: [NCBrandColor.shared.iconImageColor]),
                sender: sender,
                action: { _ in
                    NCDocumentCamera.shared.openScannerDocument(viewController: controller)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_create_voice_memo_", comment: ""),
                icon: utility.loadImage(named: "mic", colors: [NCBrandColor.shared.iconImageColor]),
                sender: sender,
                action: { _ in
                    NCAskAuthorization().askAuthorizationAudioRecord(viewController: controller) { hasPermission in
                        if hasPermission {
                            if let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as? NCAudioRecorderViewController {
                                viewController.controller = controller
                                viewController.modalTransitionStyle = .crossDissolve
                                viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
                                controller.present(viewController, animated: true, completion: nil)
                            }
                        }
                    }
                }
            )
        )

        if NCKeychain().isEndToEndEnabled(account: session.account) {
            actions.append(.seperator(order: 0, sender: sender))
        }

        let titleCreateFolder = isDirectoryE2EE ? NSLocalizedString("_create_folder_e2ee_", comment: "") : NSLocalizedString("_create_folder_", comment: "")
        let imageCreateFolder = isDirectoryE2EE ? NCImageCache.shared.getFolderEncrypted(account: session.account) : NCImageCache.shared.getFolder(account: session.account)
        actions.append(
            NCMenuAction(title: titleCreateFolder,
                         icon: imageCreateFolder,
                         sender: sender,
                         action: { _ in
                             let alertController = UIAlertController.createFolder(serverUrl: serverUrl, session: session, sceneIdentifier: controller.sceneIdentifier)
                             controller.present(alertController, animated: true, completion: nil)
                         }
                        )
        )

        // Folder encrypted
        if !isDirectoryE2EE && NCKeychain().isEndToEndEnabled(account: session.account) {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_folder_e2ee_", comment: ""),
                             icon: NCImageCache.shared.getFolderEncrypted(account: session.account),
                             sender: sender,
                             action: { _ in
                                 let alertController = UIAlertController.createFolder(serverUrl: serverUrl, session: session, markE2ee: true, sceneIdentifier: controller.sceneIdentifier)
                                 controller.present(alertController, animated: true, completion: nil)
                             })
            )
        }

        if NCKeychain().isEndToEndEnabled(account: session.account) {
            actions.append(.seperator(order: 0, sender: sender))
        }

        if capabilities.serverVersionMajor >= NCGlobal.shared.nextcloudVersion18 && directory?.richWorkspace == nil && !isDirectoryE2EE && NextcloudKit.shared.isNetworkReachable() {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_add_folder_info_", comment: ""),
                    icon: NCUtility().loadImage(named: "list.dash.header.rectangle", colors: [NCBrandColor.shared.iconImageColor]),
                    sender: sender,
                    action: { _ in
                        let richWorkspaceCommon = NCRichWorkspaceCommon()
                        if let viewController = controller.currentViewController() {
                            if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@",
                                                                                session.account,
                                                                                serverUrl,
                                                                                NCGlobal.shared.fileNameRichWorkspace.lowercased())) == nil {
                                richWorkspaceCommon.createViewerNextcloudText(serverUrl: serverUrl, viewController: viewController, session: session)
                            } else {
                                richWorkspaceCommon.openViewerNextcloudText(serverUrl: serverUrl, viewController: viewController, session: session)
                            }
                        }
                    }
                )
            )
        }

        if NextcloudKit.shared.isNetworkReachable(),
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_docx"}) {

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_document_", comment: ""),
                    icon: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.documentIconColor]),
                    sender: sender,
                    action: { _ in
                        let createDocument = NCCreateDocument()

                        Task {
                            let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "document", account: session.account)
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                            let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                            createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "onlyoffice", creatorId: creator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                        }
                    }
                )
            )
        }

        if NextcloudKit.shared.isNetworkReachable(),
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_xlsx"}) {

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_spreadsheet_", comment: ""),
                    icon: utility.loadImage(named: "tablecells", colors: [NCBrandColor.shared.spreadsheetIconColor]),
                    sender: sender,
                    action: { _ in
                        let createDocument = NCCreateDocument()

                        Task {
                            let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "spreadsheet", account: session.account)
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                            let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                            createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "onlyoffice", creatorId: creator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                        }
                    }
                )
            )
        }

        if NextcloudKit.shared.isNetworkReachable(),
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_pptx"}) {

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_presentation_", comment: ""),
                    icon: utility.loadImage(named: "play.rectangle", colors: [NCBrandColor.shared.presentationIconColor]),
                    sender: sender,
                    action: { _ in
                        let createDocument = NCCreateDocument()

                        Task {
                            let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "presentation", account: session.account)
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                            let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                            createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "onlyoffice", creatorId: creator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                        }
                    }
                )
            )
        }

        if capabilities.richDocumentsEnabled {
            if NextcloudKit.shared.isNetworkReachable() && !isDirectoryE2EE {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_document_", comment: ""),
                        icon: utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.documentIconColor]),
                        sender: sender,
                        action: { _ in
                            let createDocument = NCCreateDocument()

                            Task {
                                let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "document", account: session.account)
                                let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                                let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                                createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                            }
                        }
                    )
                )

                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_spreadsheet_", comment: ""),
                        icon: utility.loadImage(named: "tablecells", colors: [NCBrandColor.shared.spreadsheetIconColor]),
                        sender: sender,
                        action: { _ in
                            let createDocument = NCCreateDocument()

                            Task {
                                let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "spreadsheet", account: session.account)
                                let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                                let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                                createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                            }
                        }
                    )
                )

                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_presentation_", comment: ""),
                        icon: utility.loadImage(named: "play.rectangle", colors: [NCBrandColor.shared.presentationIconColor]),
                        sender: sender,
                        action: { _ in
                            let createDocument = NCCreateDocument()

                            Task {
                                let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "presentation", account: session.account)
                                let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                                let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                                createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                            }
                        }
                    )
                )
            }
        }

        controller.presentMenu(with: actions, controller: controller, sender: sender)
    }
}
