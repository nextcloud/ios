//
//  AppDelegate+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//  Copyright © 2024 STRATO AG
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
        let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
        let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: appDelegate.account)
        let serverUrl = controller.currentServerUrl()
        let isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, userBase: appDelegate)
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
        let utility = NCUtility()
		let canCreateOfficeFiles = false
		
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_photos_videos_", comment: ""), icon: NCImagesRepository.menuIconUploadPhotosVideos, action: { _ in
                    NCAskAuthorization().askAuthorizationPhotoLibrary(viewController: controller) { hasPermission in
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

        if NCKeychain().isEndToEndEnabled(account: appDelegate.account) {
            actions.append(.seperator(order: 0))
        }

        let titleCreateFolder = isDirectoryE2EE ? NSLocalizedString("_create_folder_e2ee_", comment: "") : NSLocalizedString("_create_folder_", comment: "")
        let imageCreateFolder = NCImagesRepository.menuIconCreateFolder
        actions.append(
            NCMenuAction(title: titleCreateFolder,
                         icon: imageCreateFolder, action: { _ in
                             let alertController = UIAlertController.createFolder(serverUrl: serverUrl, userBaseUrl: appDelegate, sceneIdentifier: controller.sceneIdentifier)
                             controller.present(alertController, animated: true, completion: nil)
                         }
                        )
        )

        // Folder encrypted
        if !isDirectoryE2EE && NCKeychain().isEndToEndEnabled(account: appDelegate.account) {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_folder_e2ee_", comment: ""),
                             icon: NCImagesRepository.menuIconCreateFolder,
                             action: { _ in
                                 let alertController = UIAlertController.createFolder(serverUrl: serverUrl, userBaseUrl: appDelegate, markE2ee: true, sceneIdentifier: controller.sceneIdentifier)
                                 controller.present(alertController, animated: true, completion: nil)
                             })
            )
        }

        if NCKeychain().isEndToEndEnabled(account: appDelegate.account) {
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
                    title: NSLocalizedString("_create_new_document_", comment: ""), icon: NCImagesRepository.menuIconCreateDocument, action: { _ in
                        let createDocument = NCCreateDocument()

                        Task {
                            let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorOnlyoffice, templateId: NCGlobal.shared.templateDocument)
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: appDelegate.account, serverUrl: serverUrl)
                            let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)

                            createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorOnlyoffice, creatorId: directEditingCreator.identifier, templateId: templates.selectedTemplate.identifier)
                        }
                    }
                )
            )
        }

        if NextcloudKit.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficeXlsx}) && !isDirectoryE2EE {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficeXlsx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), icon: NCImagesRepository.menuIconCreateSpreadsheet, action: { _ in
                        let createDocument = NCCreateDocument()

                        Task {
                            let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorOnlyoffice, templateId: NCGlobal.shared.templateSpreadsheet)
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: appDelegate.account, serverUrl: serverUrl)
                            let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)

                            createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorOnlyoffice, creatorId: directEditingCreator.identifier, templateId: templates.selectedTemplate.identifier)
                        }
                    }
                )
            )
        }

        if NextcloudKit.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficePptx}) && !isDirectoryE2EE {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficePptx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_presentation_", comment: ""), icon: NCImagesRepository.menuIconCreatePresentation, action: { _ in
                        let createDocument = NCCreateDocument()

                        Task {
                            let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorOnlyoffice, templateId: NCGlobal.shared.templatePresentation)
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: appDelegate.account, serverUrl: serverUrl)
                            let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)

                            createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorOnlyoffice, creatorId: directEditingCreator.identifier, templateId: templates.selectedTemplate.identifier)
                        }
                    }
                )
            )
        }

        if NCGlobal.shared.capabilityRichDocumentsEnabled {
            if NextcloudKit.shared.isNetworkReachable() && !isDirectoryE2EE {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_document_", comment: ""), icon: NCImagesRepository.menuIconCreateDocument, action: { _ in
                            let createDocument = NCCreateDocument()

                            Task {
                                let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorCollabora, templateId: NCGlobal.shared.templateDocument)
                                let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: appDelegate.account, serverUrl: serverUrl)
                                let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)

                                createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorCollabora, templateId: templates.selectedTemplate.identifier)
                            }
                        }
                    )
                )

                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), icon: NCImagesRepository.menuIconCreateSpreadsheet, action: { _ in
                            let createDocument = NCCreateDocument()

                            Task {
                                let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorCollabora, templateId: NCGlobal.shared.templateSpreadsheet)
                                let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: appDelegate.account, serverUrl: serverUrl)
                                let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)

                                createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorCollabora, templateId: templates.selectedTemplate.identifier)
                            }
                        }
                    )
                )

                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_presentation_", comment: ""), icon: NCImagesRepository.menuIconCreatePresentation, action: { _ in
                            let createDocument = NCCreateDocument()

                            Task {
                                let templates = await createDocument.getTemplate(editorId: NCGlobal.shared.editorCollabora, templateId: NCGlobal.shared.templatePresentation)
                                let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: appDelegate.account, serverUrl: serverUrl)
                                let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)

                                createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorCollabora, templateId: templates.selectedTemplate.identifier)
                            }
                        }
                    )
                )
            }
        }

        controller.presentMenu(with: actions)
    }
}
