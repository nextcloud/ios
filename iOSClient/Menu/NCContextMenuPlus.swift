// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

class NCContextMenuPlus: NSObject {
    let menuToolbar: UIToolbar?
    let controller: NCMainTabBarController?

    init(menuToolbar: UIToolbar?, controller: NCMainTabBarController?) {
        self.menuToolbar = menuToolbar
        self.controller = controller
    }

    @MainActor
    func create(session: NCSession.Session) async {
        guard let controller, let menuToolbar else {
            return
        }
        let capabilities = await NCManageDatabase.shared.getCapabilities(account: session.account) ?? NKCapabilities.Capabilities()
        let utilityFileSystem = NCUtilityFileSystem()
        let utility = NCUtility()
        let serverUrl = controller.currentServerUrl()

        let isDirectoryE2EE = await NCUtilityFileSystem().isDirectoryE2EEAsync(serverUrl: serverUrl, urlBase: session.urlBase, userId: session.userId, account: session.account)
        let directory = await NCManageDatabase.shared.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))
        let isNetworkReachable = NextcloudKit.shared.isNetworkReachable()
        let titleCreateFolder = isDirectoryE2EE ? NSLocalizedString("_create_folder_e2ee_", comment: "") : NSLocalizedString("_create_folder_", comment: "")
        let imageCreateFolder = isDirectoryE2EE ? NCImageCache.shared.getFolderEncrypted(account: session.account) : NCImageCache.shared.getFolder(account: session.account)

        var menuActionElement: [UIMenuElement] = []
        var menuE2EEElement: [UIMenuElement] = []
        var menuTextElement: [UIMenuElement] = []
        var menuOnlyOfficeElement: [UIMenuElement] = []
        var menuRichDocumentElement: [UIMenuElement] = []

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

        menuActionElement.append(UIAction(title: titleCreateFolder,
                                          image: imageCreateFolder) { _ in
            DispatchQueue.main.async {
                let alertController = UIAlertController.createFolder(
                    serverUrl: serverUrl,
                    session: session,
                    sceneIdentifier: controller.sceneIdentifier,
                    capabilities: capabilities,
                    scene: SceneManager.shared.getWindow(controller: controller)?.windowScene)
                controller.present(alertController, animated: true, completion: nil)
            }
        })

        // ------------------------------- E2EE

        if serverUrl == utilityFileSystem.getHomeServer(session: session),
           NCPreferences().isEndToEndEnabled(account: session.account),
           isNetworkReachable {
            menuE2EEElement.append(UIAction(title: NSLocalizedString("_create_folder_e2ee_", comment: ""),
                                            image: NCImageCache.shared.getFolderEncrypted(account: session.account)) { _ in
                DispatchQueue.main.async {
                    let alertController = UIAlertController.createFolder(
                        serverUrl: serverUrl,
                        session: session,
                        markE2ee: true,
                        sceneIdentifier: controller.sceneIdentifier,
                        capabilities: capabilities,
                        scene: SceneManager.shared.getWindow(controller: controller)?.windowScene)
                    controller.present(alertController, animated: true, completion: nil)
                }
            })
        }

        // ------------------------------- RICHDOCUMENT TEXT

        if capabilities.serverVersionMajor >= NCGlobal.shared.nextcloudVersion18,
           directory?.richWorkspace == nil,
           !isDirectoryE2EE,
           isNetworkReachable {
            menuTextElement.append(UIAction(title: NSLocalizedString("_add_folder_info_", comment: ""),
                                            image: utility.loadImage(named: "list.dash.header.rectangle", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                Task { @MainActor in
                    let richWorkspaceCommon = NCRichWorkspaceCommon()
                    if let viewController = controller.currentViewController() {
                        if await NCManageDatabase.shared.getMetadataAsync(
                            predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@",
                                                   session.account,
                                                   serverUrl,
                                                   NCGlobal.shared.fileNameRichWorkspace.lowercased())) == nil {
                            richWorkspaceCommon.createViewerNextcloudText(serverUrl: serverUrl, viewController: viewController, controller: controller, session: session)
                        } else {
                            richWorkspaceCommon.openViewerNextcloudText(serverUrl: serverUrl, viewController: viewController, controller: controller, session: session)
                        }
                    }
                }
            })
        }

        if isNetworkReachable,
           let creator = capabilities.directEditingCreators.first(where: { $0.editor == "text" }),
           !isDirectoryE2EE {
            menuTextElement.append(UIAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""),
                                            image: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                Task {
                    let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + creator.ext, account: session.account, serverUrl: serverUrl)
                    let fileNamePath = utilityFileSystem.getRelativeFilePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                    await NCCreate().createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "text", creatorId: creator.identifier, templateId: "document", account: session.account)
                }
            })
        }

        // ------------------------------- WEB EDITORS

        if isNetworkReachable,
           !isDirectoryE2EE {

            // ------------------------------- COLLABORA
            if capabilities.richDocumentsEnabled {
                menuRichDocumentElement.append(UIAction(title: NSLocalizedString("_create_new_document_", comment: ""),
                                                        image: utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.documentIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreate()
                        let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "document", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = utilityFileSystem.getRelativeFilePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                    }
                })

                menuRichDocumentElement.append(UIAction(title: NSLocalizedString("_create_new_spreadsheet_", comment: ""),
                                                        image: utility.loadImage(named: "tablecells", colors: [NCBrandColor.shared.spreadsheetIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreate()
                        let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "spreadsheet", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = utilityFileSystem.getRelativeFilePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                    }
                })

                menuRichDocumentElement.append(UIAction(title: NSLocalizedString("_create_new_presentation_", comment: ""),
                                                        image: utility.loadImage(named: "play.rectangle", colors: [NCBrandColor.shared.presentationIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreate()
                        let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "presentation", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = utilityFileSystem.getRelativeFilePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "collabora", templateId: templates.selectedTemplate.identifier, account: session.account)
                    }
                })
            }

            // ------------------------------- ONLY OFFICE

            if let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_docx"}) {
                menuOnlyOfficeElement.append(UIAction(title: NSLocalizedString("_create_new_document_", comment: ""),
                                                      image: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.documentIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreate()
                        let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "document", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = utilityFileSystem.getRelativeFilePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "onlyoffice", creatorId: creator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                    }
                })
            }

            if let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_xlsx"}) {
                menuOnlyOfficeElement.append(UIAction(title: NSLocalizedString("_create_new_spreadsheet_", comment: ""),
                                                      image: utility.loadImage(named: "tablecells", colors: [NCBrandColor.shared.spreadsheetIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreate()
                        let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "spreadsheet", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = utilityFileSystem.getRelativeFilePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        await createDocument.createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "onlyoffice", creatorId: creator.identifier, templateId: templates.selectedTemplate.identifier, account: session.account)
                    }

                })
            }

            if let creator = capabilities.directEditingCreators.first(where: { $0.editor == "onlyoffice" && $0.identifier == "onlyoffice_pptx"}) {
                menuOnlyOfficeElement.append(UIAction(title: NSLocalizedString("_create_new_presentation_", comment: ""),
                                                      image: utility.loadImage(named: "play.rectangle", colors: [NCBrandColor.shared.presentationIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreate()
                        let templates = await createDocument.getTemplate(editorId: "onlyoffice", templateId: "presentation", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = utilityFileSystem.getRelativeFilePath(String(describing: fileName), serverUrl: serverUrl, session: session)

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

        let plusMenu = UIMenu(children: [menuAction, menuE2EE, menuText, menuRichDocument, menuOnlyOffice])

        let config = UIImage.SymbolConfiguration(pointSize: 25, weight: .thin)
        let plusImage = UIImage(systemName: "plus.circle.fill", withConfiguration: config)

        if let plusItem = menuToolbar.items?.first {
            plusItem.menu = plusMenu
        } else {
            let plusItem = UIBarButtonItem(image: plusImage, style: .plain, target: nil, action: nil)
            plusItem.tintColor = NCBrandColor.shared.getElement(account: session.account)
            plusItem.menu = plusMenu
            menuToolbar.setItems([plusItem], animated: false)
            menuToolbar.sizeToFit()
            menuToolbar.alpha = 1
        }

        // E2EE Offile disable
        if !isNetworkReachable, isDirectoryE2EE {
            menuToolbar.items?.first?.isEnabled = false
        } else {
            menuToolbar.items?.first?.isEnabled = true
        }
    }

    @MainActor
    func hiddenPlusButton(_ isHidden: Bool, animation: Bool = true) {
        guard let menuToolbar else {
            return
        }
        let tx = 200.0
        if isHidden {
            if menuToolbar.transform.tx == tx {
                menuToolbar.alpha = 0
                return
            }
            if animation {
                UIView.animate(withDuration: 0.5, delay: 0.0, options: [], animations: {
                    menuToolbar.transform = CGAffineTransform(translationX: tx, y: 0)
                    menuToolbar.alpha = 0
                })
            } else {
                menuToolbar.transform = CGAffineTransform(translationX: tx, y: 0)
                menuToolbar.alpha = 0
            }
        } else {
            if menuToolbar.transform.tx == 0.0 {
                menuToolbar.alpha = 1
                return
            }
            if animation {
                UIView.animate(withDuration: 0.5, delay: 0.3, options: [], animations: {
                    menuToolbar.transform = .identity
                    menuToolbar.alpha = 1
                })
            } else {
                menuToolbar.transform = .identity
                menuToolbar.alpha = 1
            }
        }
    }

    @MainActor
    func resetPlusButtonAlpha(animated: Bool = true) {
        guard let menuToolbar else {
            return
        }
        let update = {
            menuToolbar.alpha = 1.0
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: update)
        } else {
            update()
        }
    }
}
