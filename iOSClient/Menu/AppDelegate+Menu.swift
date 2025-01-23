//
//  AppDelegate+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//  Copyright © 2024 STRATO GmbH
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
    func toggleMenu(controller: NCMainTabBarController) {
        var actions: [NCMenuAction] = []
        let session = NCSession.shared.getSession(controller: controller)
        let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: session.account)
        let serverUrl = controller.currentServerUrl()
        let isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, account: session.account)
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))
        let utility = NCUtility()
		let canCreateOfficeFiles = false
		
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_photos_videos_", comment: ""), icon: NCImagesRepository.menuIconUploadPhotosVideos, action: { _ in
                    NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
                        if hasPermission {NCPhotosPickerViewController(controller: controller, maxSelectedAssets: 0, singleSelectedMode: false)
                        }
                    }
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_file_", comment: ""), icon: NCImagesRepository.menuIconUploadFile, action: { _ in
                    controller.documentPickerViewController = NCDocumentPickerViewController(controller: controller, isViewerMedia: false, allowsMultipleSelection: true)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_scans_document_", comment: ""), icon: NCImagesRepository.menuIconScan, action: { _ in
                    NCDocumentCamera.shared.openScannerDocument(viewController: controller)
                }
            )
        )

        if NCKeychain().isEndToEndEnabled(account: session.account) {
            actions.append(.seperator(order: 0))
        }

        let titleCreateFolder = isDirectoryE2EE ? NSLocalizedString("_create_folder_e2ee_", comment: "") : NSLocalizedString("_create_folder_", comment: "")
        let imageCreateFolder = NCImagesRepository.menuIconCreateFolder
        actions.append(
            NCMenuAction(title: titleCreateFolder,
                         icon: imageCreateFolder, action: { _ in
                             let alertController = UIAlertController.createFolder(serverUrl: serverUrl, session: session, sceneIdentifier: controller.sceneIdentifier)
                             controller.present(alertController, animated: true, completion: nil)
                         }
                        )
        )

        // Folder encrypted
        if !isDirectoryE2EE && NCKeychain().isEndToEndEnabled(account: session.account) {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_folder_e2ee_", comment: ""),
                             icon: NCImagesRepository.menuIconCreateFolder,
                             action: { _ in
                                 let alertController = UIAlertController.createFolder(serverUrl: serverUrl, session: session, markE2ee: true, sceneIdentifier: controller.sceneIdentifier)
                                 controller.present(alertController, animated: true, completion: nil)
                             })
            )
        }

        if NCKeychain().isEndToEndEnabled(account: session.account) {
            actions.append(.seperator(order: 0))
        }

		guard canCreateOfficeFiles else {
			controller.presentMenu(with: actions)
			return
		}
		
        if NextcloudKit.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficeDocx}) && !isDirectoryE2EE {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficeDocx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_document_", comment: ""), icon: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.documentIconColor]), action: { _ in
                        let createDocument = NCCreateDocument()

                        Task {
                            let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorOnlyoffice, templateId: NCGlobal.shared.templateDocument, account: session.account)
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                            let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                            createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorOnlyoffice, creatorId: directEditingCreator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                        }
                    }
                )
            )
        }

        if NextcloudKit.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficeXlsx}) && !isDirectoryE2EE {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficeXlsx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), icon: utility.loadImage(named: "tablecells", colors: [NCBrandColor.shared.spreadsheetIconColor]), action: { _ in
                        let createDocument = NCCreateDocument()

                        Task {
                            let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorOnlyoffice, templateId: NCGlobal.shared.templateSpreadsheet, account: session.account)
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                            let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                            createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorOnlyoffice, creatorId: directEditingCreator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                        }
                    }
                )
            )
        }

        if NextcloudKit.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficePptx}) && !isDirectoryE2EE {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficePptx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_presentation_", comment: ""), icon: utility.loadImage(named: "play.rectangle", colors: [NCBrandColor.shared.presentationIconColor]), action: { _ in
                        let createDocument = NCCreateDocument()

                        Task {
                            let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorOnlyoffice, templateId: NCGlobal.shared.templatePresentation, account: session.account)
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                            let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                            createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorOnlyoffice, creatorId: directEditingCreator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                        }
                    }
                )
            )
        }

        if NCCapabilities.shared.getCapabilities(account: session.account).capabilityRichDocumentsEnabled {
            if NextcloudKit.shared.isNetworkReachable() && !isDirectoryE2EE {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_document_", comment: ""), icon: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.documentIconColor]), action: { _ in
                            let createDocument = NCCreateDocument()

                            Task {
                                let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorCollabora, templateId: NCGlobal.shared.templateDocument, account: session.account)
                                let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                                let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                                createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorCollabora, templateId: templates.selectedTemplate.identifier, account: session.account)
                            }
                        }
                    )
                )

                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), icon: utility.loadImage(named: "tablecells", colors: [NCBrandColor.shared.spreadsheetIconColor]), action: { _ in
                            let createDocument = NCCreateDocument()

                            Task {
                                let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorCollabora, templateId: NCGlobal.shared.templateSpreadsheet, account: session.account)
                                let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                                let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                                createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorCollabora, templateId: templates.selectedTemplate.identifier, account: session.account)
                            }
                        }
                    )
                )

                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_presentation_", comment: ""), icon: utility.loadImage(named: "play.rectangle", colors: [NCBrandColor.shared.presentationIconColor]), action: { _ in
                            let createDocument = NCCreateDocument()

                            Task {
                                let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorCollabora, templateId: NCGlobal.shared.templatePresentation, account: session.account)
                                let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                                let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                                createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorCollabora, templateId: templates.selectedTemplate.identifier, account: session.account)
                            }
                        }
                    )
                )
            }
        }

        controller.presentMenu(with: actions)
    }
}
