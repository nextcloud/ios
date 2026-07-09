// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

@MainActor
class NCContextMenuPlus: NSObject {
    struct CreatorMenuInfo {
        let titleKey: String
        let templateId: String
        let icon: String
        let sortOrder: Int
    }

    let menuPlusButton: UIButton?
    let controller: NCMainTabBarController?
    private var capabilitiesSignature: String?

    internal var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: controller)
    }

    init(menuPlusButton: UIButton?, controller: NCMainTabBarController?) {
        self.menuPlusButton = menuPlusButton
        self.controller = controller
    }

    nonisolated static func menuInfo(for ext: String) -> CreatorMenuInfo? {
        switch ext.lowercased() {
        case "docx":
            return CreatorMenuInfo(titleKey: "_create_new_document_", templateId: "document", icon: "doc.text", sortOrder: 0)
        case "xlsx":
            return CreatorMenuInfo(titleKey: "_create_new_spreadsheet_", templateId: "spreadsheet", icon: "tablecells", sortOrder: 1)
        case "pptx":
            return CreatorMenuInfo(titleKey: "_create_new_presentation_", templateId: "presentation", icon: "play.rectangle", sortOrder: 2)
        default:
            return nil
        }
    }

    func create(session: NCSession.Session) async {
        guard let controller, let menuPlusButton else {
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
        let creatorsByEditor = Dictionary(grouping: capabilities.directEditingCreators, by: \.editor)
        let directEditingSignature = capabilities.directEditingCreators
            .sorted { $0.identifier < $1.identifier }
            .map { creator in
                "\(creator.identifier)|\(creator.editor)|\(creator.ext)|\(creator.mimetype)|\(creator.templates)"
            }
            .joined(separator: ";")
        let currentCapabilitiesSignature = "\(session.account)|\(serverUrl)|\(capabilities.richDocumentsEnabled)|\(directEditingSignature)"
        let capabilitiesChanged = capabilitiesSignature != currentCapabilitiesSignature
        capabilitiesSignature = currentCapabilitiesSignature

        var menuActionElements: [UIMenuElement] = []
        var menuFolderElements: [UIMenuElement] = []
        var menuTextElements: [UIMenuElement] = []
        var menuRichDocumentElements: [UIMenuElement] = []
        var menuDirectEditingTextElements: [UIMenuElement] = []
        var menuDirectEditingOthersElements: [UIMenuElement] = []

        // ACTION
        //
        menuActionElements.append(UIAction(title: NSLocalizedString("_upload_photos_videos_", comment: ""),
                                           image: utility.loadImage(named: "photo", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
                if hasPermission {
                    DispatchQueue.main.async {
                        NCPhotosPickerViewController(controller: controller, maxSelectedAssets: 0, singleSelectedMode: false)
                    }
                }
            }
        })

        menuActionElements.append(UIAction(title: NSLocalizedString("_upload_file_", comment: ""),
                                           image: utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            DispatchQueue.main.async {
                controller.documentPickerViewController = NCDocumentPickerViewController(controller: controller, isViewerMedia: false, allowsMultipleSelection: true)
            }
        })

        menuActionElements.append(UIAction(title: NSLocalizedString("_scans_document_", comment: ""),
                                           image: utility.loadImage(named: "doc.text.viewfinder", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            DispatchQueue.main.async {
                NCDocumentCamera.shared.openScannerDocument(viewController: controller)
            }
        })

        menuActionElements.append(UIAction(title: NSLocalizedString("_create_voice_memo_", comment: ""),
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

        menuFolderElements.append(UIAction(title: titleCreateFolder,
                                           image: imageCreateFolder) { _ in
            DispatchQueue.main.async {
                let alertController = UIAlertController.createFolderWith(
                    serverUrl: serverUrl,
                    session: session,
                    sceneIdentifier: controller.sceneIdentifier,
                    capabilities: capabilities) { error in
                        if error != .success {
                            Task {
                                await showErrorBanner(windowScene: self.windowScene,
                                                      text: error.errorDescription,
                                                      errorCode: error.errorCode)
                            }
                        }
                    }
                controller.present(alertController, animated: true, completion: nil)
            }
        })

        // E2EE
        //
        if serverUrl == utilityFileSystem.getHomeServer(session: session),
           NCPreferences().isEndToEndEnabled(account: session.account),
           isNetworkReachable {
            menuFolderElements.append(UIAction(title: NSLocalizedString("_create_folder_e2ee_", comment: ""),
                                               image: NCImageCache.shared.getFolderEncrypted(account: session.account)) { _ in
                DispatchQueue.main.async {
                    let alertController = UIAlertController.createFolderWith(
                        serverUrl: serverUrl,
                        session: session,
                        markE2ee: true,
                        sceneIdentifier: controller.sceneIdentifier,
                        capabilities: capabilities) { error in
                            if error != .success {
                                Task {
                                    await showErrorBanner(windowScene: self.windowScene,
                                                          text: error.errorDescription,
                                                          errorCode: error.errorCode)
                                }
                            }
                        }
                    controller.present(alertController, animated: true, completion: nil)
                }
            })
        }

        // FOLDER INFO + TEXT
        //
        if NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: .v34) {
            // FOLDER INFO
            if let textCreators = creatorsByEditor["text"],
               !textCreators.isEmpty,
               directory?.richWorkspace == nil,
               !isDirectoryE2EE,
               isNetworkReachable {
                menuTextElements.append(
                    UIAction(
                        title: NSLocalizedString("_add_folder_info_", comment: ""),
                        image: utility.loadImage(named: "list.dash.header.rectangle", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                            Task { @MainActor in
                                let createDocument = NCCreate()
                                let fileName = await NCNetworking.shared.createFileName(
                                    fileNameBase: NCGlobal.shared.fileNameRichWorkspace,
                                    account: session.account,
                                    serverUrl: serverUrl
                                )

                                await createDocument.createDocument(
                                    controller: controller,
                                    serverUrl: serverUrl,
                                    fileName: fileName,
                                    editorId: "text",
                                    creatorId: "textdocument",
                                    templateId: "",
                                    session: session)
                            }
                })
            }
        } else {
            // FOLDER INFO
            if NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: .v18),
               directory?.richWorkspace == nil,
               !isDirectoryE2EE,
               isNetworkReachable {
                menuTextElements.append(UIAction(title: NSLocalizedString("_add_folder_info_", comment: ""),
                                                       image: utility.loadImage(named: "list.dash.header.rectangle", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                    Task { @MainActor in
                        let richWorkspaceCommon = NCRichWorkspaceCommon()
                        if let viewController = controller.currentViewController() {
                            richWorkspaceCommon.createViewerNextcloudText(serverUrl: serverUrl, viewController: viewController, controller: controller, session: session)
                        }
                    }
                })
            }
            // TEXT
            if isNetworkReachable,
               let creator = capabilities.directEditingCreators.first(where: { $0.editor == "text" }),
               !isDirectoryE2EE {
                menuTextElements.append(UIAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""),
                                                 image: utility.loadImage(named: "doc.text", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                    Task {
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + creator.ext, account: session.account, serverUrl: serverUrl)

                        await NCCreate().createDocument(controller: controller,
                                                        serverUrl: serverUrl,
                                                        fileName: fileName,
                                                        editorId: "text",
                                                        creatorId: creator.identifier,
                                                        templateId: "document",
                                                        session: session)
                    }
                })
            }
        }

        // OFFICE
        //
        if isNetworkReachable,
           !isDirectoryE2EE {
            if capabilities.richDocumentsEnabled {
                // COLLABORA
                //
                menuRichDocumentElements.append(UIAction(title: NSLocalizedString("_create_new_document_", comment: ""),
                                                        image: utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.documentIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreate()
                        let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "document", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)

                        await createDocument.createDocument(controller: controller,
                                                            serverUrl: serverUrl,
                                                            fileName: fileName,
                                                            editorId: "collabora",
                                                            templateId: templates.selectedTemplate.identifier,
                                                            session: session)
                    }
                })

                menuRichDocumentElements.append(UIAction(title: NSLocalizedString("_create_new_spreadsheet_", comment: ""),
                                                        image: utility.loadImage(named: "tablecells", colors: [NCBrandColor.shared.spreadsheetIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreate()
                        let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "spreadsheet", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)

                        await createDocument.createDocument(controller: controller,
                                                            serverUrl: serverUrl,
                                                            fileName: fileName,
                                                            editorId: "collabora",
                                                            templateId: templates.selectedTemplate.identifier,
                                                            session: session)
                    }
                })

                menuRichDocumentElements.append(UIAction(title: NSLocalizedString("_create_new_presentation_", comment: ""),
                                                        image: utility.loadImage(named: "play.rectangle", colors: [NCBrandColor.shared.presentationIconColor])) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreate()
                        let templates = await createDocument.getTemplate(editorId: "collabora", templateId: "presentation", account: session.account)
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + templates.ext, account: session.account, serverUrl: serverUrl)

                        await createDocument.createDocument(controller: controller,
                                                            serverUrl: serverUrl,
                                                            fileName: fileName,
                                                            editorId: "collabora",
                                                            templateId: templates.selectedTemplate.identifier,
                                                            session: session)
                    }
                })
            }

            // DIRECT EDITING (eurooffice, onlyoffice)
            //
            for editorId in creatorsByEditor.keys.sorted() {
                guard NCDirectEditorAdapter.resolve(from: [editorId]) != nil,
                      editorId != "text" else {
                    continue
                }

                let sortedCreators = creatorsByEditor[editorId]!
                    .compactMap { creator -> (NKEditorDetailsCreator, CreatorMenuInfo)? in
                        guard let info = NCContextMenuPlus.menuInfo(for: creator.ext) else { return nil }
                        return (creator, info)
                    }
                    .sorted { $0.1.sortOrder < $1.1.sortOrder }

                let editorActions: [UIMenuElement] = sortedCreators.map { creator, info in
                    UIAction(
                        title: NSLocalizedString(info.titleKey, comment: ""),
                        image: utility.loadImage(named: info.icon, colors: [info.iconColor])
                    ) { _ in
                        Task { @MainActor in
                            let createDocument = NCCreate()
                            let fileExt: String
                            let templateIdentifier: String
                            if creator.templates {
                                let result = await createDocument.getTemplate(editorId: editorId, templateId: info.templateId, account: session.account)
                                fileExt = result.ext
                                templateIdentifier = result.selectedTemplate.identifier
                            } else {
                                fileExt = creator.ext
                                templateIdentifier = ""
                            }
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + fileExt, account: session.account, serverUrl: serverUrl)

                            await createDocument.createDocument(controller: controller,
                                                                serverUrl: serverUrl,
                                                                fileName: fileName,
                                                                editorId: editorId,
                                                                creatorId: creator.identifier,
                                                                templateId: templateIdentifier,
                                                                session: session)
                        }
                    }
                }

                menuDirectEditingTextElements.append(contentsOf: editorActions)
            }

            // DIRECT EDITING OTHERS
            //
            let filteredCreatorsByEditor = creatorsByEditor.filter {
                $0.key != "eurooffice"
            }
            let creators = filteredCreatorsByEditor.values.flatMap { $0 }
            let sortedCreators = creators.sorted {
                $0.name < $1.name
            }

            for creator in sortedCreators {
                let image: UIImage?
                switch creator.ext {
                    case "md":
                        image = UIImage(systemName: "text.document")
                    case "whiteboard":
                        image = UIImage(systemName: "pencil.and.scribble")
                    default:
                        image = UIImage(systemName: "doc")
                    }

                let action = UIAction(
                    title: creator.name,
                    image: image
                ) { _ in
                    Task { @MainActor in
                        let createDocument = NCCreate()
                        let fileName = await NCNetworking.shared.createFileName(
                            fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + creator.ext,
                            account: session.account,
                            serverUrl: serverUrl
                        )

                        await createDocument.createDocument(
                            controller: controller,
                            serverUrl: serverUrl,
                            fileName: fileName,
                            editorId: creator.editor,
                            creatorId: creator.identifier,
                            templateId: "",
                            session: session)
                    }
                }

                menuDirectEditingOthersElements.append(action)
            }
        }

        // ACTIONS
        let menuAction = UIMenu(title: "", options: .displayInline, children: menuActionElements)

        // TEXT
        let menuText = UIMenu(title: "", options: .displayInline, children: menuTextElements)

        // FOLDER
        let menuFolder = UIMenu(title: "", options: .displayInline, children: menuFolderElements)
        if menuFolderElements.count > 1 {
            menuFolder.preferredElementSize = .medium
        }

        // EUROOFFICE - ONLYOFFICE
        var menuOffice: UIMenu?
        if menuDirectEditingTextElements.count > 0 || menuDirectEditingOthersElements.count > 0 {
            // OFFICE
            let menuDirectEditingOffice = UIMenu(title: "", options: .displayInline, children: menuDirectEditingTextElements)
            menuDirectEditingOffice.preferredElementSize = .medium
            // OTHER
            let menuDirectEditingOthers = UIMenu(title: "", options: .displayInline, children: menuDirectEditingOthersElements)
            menuDirectEditingOthers.preferredElementSize = .medium

            menuOffice = UIMenu(
                title: "Office",
                image: UIImage(systemName: "doc.richtext"),
                children: [menuDirectEditingOthers, menuDirectEditingOffice]
            )
        }

        // COLLABORA
        let menuRichDocumentOffice = UIMenu(title: "", options: .displayInline, children: menuRichDocumentElements)
        menuRichDocumentOffice.preferredElementSize = .medium

        // MENU PLUS
        var plusMenuElements: [UIMenuElement] = [menuAction, menuText]
        if let menuOffice {
            plusMenuElements.append(menuOffice)
        }
        plusMenuElements.append(contentsOf: [menuFolder, menuRichDocumentOffice])

        let plusMenu = UIMenu(children: plusMenuElements)

        // PLUS BUTTON
        if menuPlusButton.menu != nil,
           !capabilitiesChanged {
            return
        }

        menuPlusButton.menu = plusMenu
        menuPlusButton.showsMenuAsPrimaryAction = true
        menuPlusButton.backgroundColor = NCBrandColor.shared.getElement(account: session.account)
        menuPlusButton.tintColor = .white
        menuPlusButton.alpha = 1

        // E2EE Offline disable
        menuPlusButton.isEnabled = isNetworkReachable || !isDirectoryE2EE
    }

    @MainActor
    func hiddenPlusButton(_ isHidden: Bool, animation: Bool = true) {
        guard let menuPlusButton else {
            return
        }
        let tx = 200.0
        if isHidden {
            if menuPlusButton.transform.tx == tx {
                menuPlusButton.alpha = 0
                return
            }
            if animation {
                UIView.animate(withDuration: 0.5, delay: 0.0, options: [], animations: {
                    menuPlusButton.transform = CGAffineTransform(translationX: tx, y: 0)
                    menuPlusButton.alpha = 0
                })
            } else {
                menuPlusButton.transform = CGAffineTransform(translationX: tx, y: 0)
                menuPlusButton.alpha = 0
            }
        } else {
            if menuPlusButton.transform.tx == 0.0 {
                menuPlusButton.alpha = 1
                return
            }
            if animation {
                UIView.animate(withDuration: 0.5, delay: 0.3, options: [], animations: {
                    menuPlusButton.transform = .identity
                    menuPlusButton.alpha = 1
                })
            } else {
                menuPlusButton.transform = .identity
                menuPlusButton.alpha = 1
            }
        }
    }

    @MainActor
    func resetPlusButtonAlpha(animated: Bool = true) {
        guard let menuPlusButton else {
            return
        }
        let update = {
            menuPlusButton.alpha = 1.0
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: update)
        } else {
            update()
        }
    }
}

@MainActor
extension NCContextMenuPlus.CreatorMenuInfo {
    var iconColor: UIColor {
        switch templateId {
        case "spreadsheet": return NCBrandColor.shared.spreadsheetIconColor
        case "presentation": return NCBrandColor.shared.presentationIconColor
        default: return NCBrandColor.shared.documentIconColor
        }
    }
}
