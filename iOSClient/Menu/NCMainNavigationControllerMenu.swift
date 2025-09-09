// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

extension NCMainNavigationController {
    func createPlusMenu(session: NCSession.Session, capabilities: NKCapabilities.Capabilities) {
        var menuActionElement: [UIMenuElement] = []
        var menuE2EEElement: [UIMenuElement] = []
        var menuTextElement: [UIMenuElement] = []
        var menuOnlyOfficeElement: [UIMenuElement] = []
        var menuRichDocumentElement: [UIMenuElement] = []
        guard let controller,
              let plusItem else {
            return
        }

        let utilityFileSystem = NCUtilityFileSystem()
        let utility = NCUtility()
        let serverUrl = controller.currentServerUrl()
        let isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, urlBase: session.urlBase, userId: session.userId, account: session.account)
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))
        let titleCreateFolder = isDirectoryE2EE ? NSLocalizedString("_create_folder_e2ee_", comment: "") : NSLocalizedString("_create_folder_", comment: "")
        let imageCreateFolder = isDirectoryE2EE ? NCImageCache.shared.getFolderEncrypted(account: session.account) : NCImageCache.shared.getFolder(account: session.account)

        // ------------------------------- ACTION

        menuActionElement.append(UIAction(title: NSLocalizedString("_upload_photos_videos_", comment: ""),
                                          image: utility.loadImage(named: "photo", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
                if hasPermission {
                    DispatchQueue.main.async {
                        NCPhotosPickerViewController(controller: controller, maxSelectedAssets: 0, singleSelectedMode: false)
                    }
                }
            }
        })

        menuActionElement.append(UIAction(title: NSLocalizedString("_upload_file_", comment: ""),
                                          image: utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            DispatchQueue.main.async {
                controller.documentPickerViewController = NCDocumentPickerViewController(controller: controller, isViewerMedia: false, allowsMultipleSelection: true)
            }
        })

        menuActionElement.append(UIAction(title: titleCreateFolder,
                                          image: imageCreateFolder) { _ in
            DispatchQueue.main.async {
                let alertController = UIAlertController.createFolder(serverUrl: serverUrl, session: session, sceneIdentifier: controller.sceneIdentifier, capabilities: capabilities)
                controller.present(alertController, animated: true, completion: nil)
            }
        })

        menuActionElement.append(UIAction(title: NSLocalizedString("_scans_document_", comment: ""),
                                          image: utility.loadImage(named: "doc.text.viewfinder", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            DispatchQueue.main.async {
                NCDocumentCamera.shared.openScannerDocument(viewController: controller)
            }
        })

        menuActionElement.append(UIAction(title: NSLocalizedString("_create_voice_memo_", comment: ""),
                                          image: utility.loadImage(named: "mic", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            NCAskAuthorization().askAuthorizationAudioRecord(controller: controller) { hasPermission in
                if hasPermission {
                    DispatchQueue.main.async {
                        if let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as? NCAudioRecorderViewController {
                            viewController.controller = controller
                            viewController.modalTransitionStyle = .crossDissolve
                            viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
                            controller.present(viewController, animated: true, completion: nil)
                        }
                    }
                }
            }
        })

        // ------------------------------- E2EE

        if serverUrl == utilityFileSystem.getHomeServer(session: session) && NCPreferences().isEndToEndEnabled(account: session.account) {
            menuE2EEElement.append(UIAction(title: NSLocalizedString("_create_folder_e2ee_", comment: ""),
                                            image: NCImageCache.shared.getFolderEncrypted(account: session.account)) { _ in
                DispatchQueue.main.async {
                    let alertController = UIAlertController.createFolder(serverUrl: serverUrl, session: session, markE2ee: true, sceneIdentifier: controller.sceneIdentifier, capabilities: capabilities)
                    controller.present(alertController, animated: true, completion: nil)
                }
            })
        }

        // ------------------------------- RICHDOCUMENT TEXT

        if capabilities.serverVersionMajor >= NCGlobal.shared.nextcloudVersion18,
           directory?.richWorkspace == nil,
           !isDirectoryE2EE,
           NextcloudKit.shared.isNetworkReachable() {
            menuTextElement.append(UIAction(title: NSLocalizedString("_add_folder_info_", comment: ""),
                                            image: utility.loadImage(named: "list.dash.header.rectangle", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                DispatchQueue.main.async {
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
            })
        }

        if NextcloudKit.shared.isNetworkReachable(),
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "text" }),
           !isDirectoryE2EE {
            menuTextElement.append(UIAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""),
                                            image: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                Task {
                    let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + creator.ext, account: session.account, serverUrl: serverUrl)
                    let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                    await NCCreateDocument().createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "text", creatorId: creator.identifier, templateId: "document", account: session.account)
                }
            })
        }

        // ------------------------------- COLLABORA

        if capabilities.richDocumentsEnabled,
           NextcloudKit.shared.isNetworkReachable(),
           !isDirectoryE2EE {

            menuRichDocumentElement.append(UIAction(title: NSLocalizedString("_create_new_document_", comment: ""),
                                                    image: utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.documentIconColor])) { _ in
                Task { @MainActor in
                    let createDocument = NCCreateDocument()
                    let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "document", account: session.account)
                    let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                    let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                    await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                }
            })

            menuRichDocumentElement.append(UIAction(title: NSLocalizedString("_create_new_spreadsheet_", comment: ""),
                                                    image: utility.loadImage(named: "tablecells", colors: [NCBrandColor.shared.spreadsheetIconColor])) { _ in
                Task { @MainActor in
                    let createDocument = NCCreateDocument()
                    let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "spreadsheet", account: session.account)
                    let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                    let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                    await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                }
            })

            menuRichDocumentElement.append(UIAction(title: NSLocalizedString("_create_new_presentation_", comment: ""),
                                                    image: utility.loadImage(named: "play.rectangle", colors: [NCBrandColor.shared.presentationIconColor])) { _ in
                Task { @MainActor in
                    let createDocument = NCCreateDocument()
                    let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "presentation", account: session.account)
                    let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                    let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                    await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                }
            })
        }

        // ------------------------------- ONLY OFFICE

        if NextcloudKit.shared.isNetworkReachable() {
            if let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_docx"}) {
                menuOnlyOfficeElement.append(UIAction(title: NSLocalizedString("_create_new_document_", comment: ""),
                                                      image: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.documentIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreateDocument()
                        let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "document", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "onlyoffice", creatorId: creator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                    }
                })
            }

            if let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_xlsx"}) {
                menuOnlyOfficeElement.append(UIAction(title: NSLocalizedString("_create_new_spreadsheet_", comment: ""),
                                                      image: utility.loadImage(named: "tablecells", colors: [NCBrandColor.shared.spreadsheetIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreateDocument()
                        let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "spreadsheet", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "onlyoffice", creatorId: creator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                    }

                })
            }

            if let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_pptx"}) {
                menuOnlyOfficeElement.append(UIAction(title: NSLocalizedString("_create_new_presentation_", comment: ""),
                                                      image: utility.loadImage(named: "play.rectangle", colors: [NCBrandColor.shared.presentationIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreateDocument()
                        let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "presentation", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = utilityFileSystem.getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "onlyoffice", creatorId: creator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                    }
                })
            }
        }

        let menuAction = UIMenu(title: "", options: .displayInline, children: menuActionElement)
        let menuText = UIMenu(title: "", options: .displayInline, children: menuTextElement)
        let menuE2EE = UIMenu(title: "", options: .displayInline, children: menuE2EEElement)
        let menuOnlyOffice = UIMenu(title: "", options: .displayInline, children: menuOnlyOfficeElement)
        let menuRichDocument = UIMenu(title: "", options: .displayInline, children: menuRichDocumentElement)

        plusMenu = UIMenu(children: [menuAction, menuText, menuE2EE, menuRichDocument, menuOnlyOffice])
        plusItem.menu = plusMenu
        menuToolbar.setItems([plusItem], animated: false)
        menuToolbar.sizeToFit()
    }

    func isHiddenPlusButton(_ isHidden: Bool) {
        if isHidden {
            UIView.animate(withDuration: 0.5, delay: 0.0, options: [], animations: {
                self.menuToolbar.transform = CGAffineTransform(translationX: 100, y: 0)
                self.menuToolbar.alpha = 0
            })
        } else {
            self.menuToolbar.transform = CGAffineTransform(translationX: 100, y: 0)
            self.menuToolbar.alpha = 0

            UIView.animate(withDuration: 0.5, delay: 0.3, options: [], animations: {
                self.menuToolbar.transform = .identity
                self.menuToolbar.alpha = 1
            })
        }
    }
}
