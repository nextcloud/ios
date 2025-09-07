// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

extension NCMainNavigationController {
    func plusMenu() -> UIMenu? {
        guard let controller else {
            return nil
        }
        let session = NCSession.shared.getSession(controller: controller)
        let utilityFileSystem = NCUtilityFileSystem()
        let serverUrl = controller.currentServerUrl()
        let isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, urlBase: session.urlBase, userId: session.userId, account: session.account)
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))
        let utility = NCUtility()
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()

        var menuAction: [UIMenu] = []
        var menuE2EE: [UIMenu] = []
        var menuOnlyOffice: [UIMenu] = []
        var menuRichDocument: [UIMenu] = []

        let actionUploadPhoto = UIAction(title: NSLocalizedString("_upload_photos_videos_", comment: ""),
                                   image: utility.loadImage(named: "photo", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
                if hasPermission {NCPhotosPickerViewController(controller: controller, maxSelectedAssets: 0, singleSelectedMode: false)
                }
            }
        }

        let actionUploadFile = UIAction(title: NSLocalizedString("_upload_file_", comment: ""),
                                   image: utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            controller.documentPickerViewController = NCDocumentPickerViewController(controller: controller, isViewerMedia: false, allowsMultipleSelection: true)
        }

        if NextcloudKit.shared.isNetworkReachable(),
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "text" }),
           !isDirectoryE2EE {
            menuAction.append(UIAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""),
                                       image: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                Task {
                    let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + creator.ext, account: session.account, serverUrl: serverUrl)
                    let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                    await NCCreateDocument().createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "text", creatorId: creator.identifier, templateId: "document", account: session.account)
                }

            })
        }

        let actionScansDocument = UIAction(title: NSLocalizedString("_scans_document_", comment: ""),
                                           image: utility.loadImage(named: "doc.text.viewfinder", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            NCDocumentCamera.shared.openScannerDocument(viewController: controller)
        }

        let actionCreateVoice = UIAction(title: NSLocalizedString("_create_voice_memo_", comment: ""),
                                         image: utility.loadImage(named: "mic", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            NCAskAuthorization().askAuthorizationAudioRecord(controller: controller) { hasPermission in
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

        let titleCreateFolder = isDirectoryE2EE ? NSLocalizedString("_create_folder_e2ee_", comment: "") : NSLocalizedString("_create_folder_", comment: "")
        let imageCreateFolder = isDirectoryE2EE ? NCImageCache.shared.getFolderEncrypted(account: session.account) : NCImageCache.shared.getFolder(account: session.account)

        let actionCreateFolder = UIAction(title: titleCreateFolder,
                                          image: imageCreateFolder) { _ in
            NCDocumentCamera.shared.openScannerDocument(viewController: controller)
        }

        // Folder encrypted
        if serverUrl == utilityFileSystem.getHomeServer(session: session) && NCPreferences().isEndToEndEnabled(account: session.account) {
            let actionEncryptFolder = UIAction(title: NSLocalizedString("_create_folder_e2ee_", comment: ""),
                                     image: NCImageCache.shared.getFolderEncrypted(account: session.account)) { _ in
                let alertController = UIAlertController.createFolder(serverUrl: serverUrl, session: session, markE2ee: true, sceneIdentifier: controller.sceneIdentifier, capabilities: capabilities)
                controller.present(alertController, animated: true, completion: nil)
            }
        }

        if capabilities.serverVersionMajor >= NCGlobal.shared.nextcloudVersion18 && directory?.richWorkspace == nil && !isDirectoryE2EE && NextcloudKit.shared.isNetworkReachable() {
            menuAction.append(UIAction(title: NSLocalizedString("_add_folder_info_", comment: ""),
                                       image: utility.loadImage(named: "list.dash.header.rectangle", colors: [NCBrandColor.shared.iconImageColor])) { _ in
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
            })
        }

        if NextcloudKit.shared.isNetworkReachable(),
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_docx"}) {
            menuOnlyOffice.append(UIAction(title: NSLocalizedString("_create_new_document_", comment: ""),
                                           image: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                let createDocument = NCCreateDocument()

                Task {
                    let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "document", account: session.account)
                    let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                    let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                    await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "onlyoffice", creatorId: creator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                }
            })
        }

        if NextcloudKit.shared.isNetworkReachable(),
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_xlsx"}) {
            menuOnlyOffice.append(UIAction(title: NSLocalizedString("_create_new_spreadsheet_", comment: ""),
                                           image: utility.loadImage(named: "tablecells", colors: [NCBrandColor.shared.spreadsheetIconColor])) { _ in
                let createDocument = NCCreateDocument()

                Task {
                    let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "spreadsheet", account: session.account)
                    let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                    let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                    await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "onlyoffice", creatorId: creator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                }

            })
        }

        if NextcloudKit.shared.isNetworkReachable(),
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_pptx"}) {
            menuOnlyOffice.append(UIAction(title: NSLocalizedString("_create_new_presentation_", comment: ""),
                                           image: utility.loadImage(named: "doc", colors: [NCBrandColor.shared.presentationIconColor])) { _ in
                let createDocument = NCCreateDocument()

                Task {
                    let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "presentation", account: session.account)
                    let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                    let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                    await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                }
            })
        }

        if capabilities.richDocumentsEnabled,
           NextcloudKit.shared.isNetworkReachable() && !isDirectoryE2EE {
            menuRichDocument.append(UIAction(title: NSLocalizedString("_create_new_document_", comment: ""),
                                             image: utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                let createDocument = NCCreateDocument()

                Task {
                    let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "document", account: session.account)
                    let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                    let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                    await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                }
            })
        }

        /*
         func createRightMenuActions() async -> (select: UIAction,
                                                 viewStyleSubmenu: UIMenu,
                                                 sortSubmenu: UIMenu,
                                                 favoriteOnTop: UIAction,
                                                 directoryOnTop: UIAction,
                                                 hiddenFiles: UIAction,
                                                 personalFilesOnly: UIAction,
                                                 showDescription: UIAction,
                                                 showRecommendedFiles: UIAction?)? {
         return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, fileSettings, additionalSettings])

         */
        return UIMenu(children: [menuAction, menuE2])
    }
}
