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
        let documentType: String
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
            return CreatorMenuInfo(titleKey: "_create_new_document_", documentType: "document", icon: "doc.text", sortOrder: 0)
        case "xlsx":
            return CreatorMenuInfo(titleKey: "_create_new_spreadsheet_", documentType: "spreadsheet", icon: "tablecells", sortOrder: 1)
        case "pptx":
            return CreatorMenuInfo(titleKey: "_create_new_presentation_", documentType: "presentation", icon: "play.rectangle", sortOrder: 2)
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
        let global = NCGlobal.shared
        let serverUrl = controller.currentServerUrl()

        let isDirectoryE2EE = await NCUtilityFileSystem().isDirectoryE2EEAsync(serverUrl: serverUrl, urlBase: session.urlBase, userId: session.userId, account: session.account)
        let directory = await NCManageDatabase.shared.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))
        let isNetworkReachable = NextcloudKit.shared.isNetworkReachable()
        let titleCreateFolder = isDirectoryE2EE ? NSLocalizedString("_create_folder_e2ee_", comment: "") : NSLocalizedString("_create_folder_", comment: "")
        let imageCreateFolder = isDirectoryE2EE ? NCImageCache.shared.getFolderEncrypted(account: session.account) : NCImageCache.shared.getFolder(account: session.account)
        let creatorsByEditor = Dictionary(grouping: capabilities.directEditingCreators, by: \.editor)
        let currentCapabilitiesSignature = makeCapabilitiesSignature(
            capabilities: capabilities,
            account: session.account,
            serverUrl: serverUrl
        )
        let capabilitiesChanged = capabilitiesSignature != currentCapabilitiesSignature
        capabilitiesSignature = currentCapabilitiesSignature

        var menuActionElements: [UIMenuElement] = []
        var menuFolderElements: [UIMenuElement] = []
        var menuTextElements: [UIMenuElement] = []
        var menuRichDocumentElements: [UIMenuElement] = []
        var menuDirectEditingOthersElements: [UIMenuElement] = []
        var officeEditorGroups: [(title: String, actions: [UIMenuElement])] = []

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
            if let textCreators = creatorsByEditor[global.editorText],
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

                                await createDocument.createFileForDirectEditing(
                                    controller: controller,
                                    serverUrl: serverUrl,
                                    fileName: fileName,
                                    editorId: global.editorText,
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
                        let coordinator = NCRichWorkspaceCoordinator()
                        if let viewController = controller.currentViewController() {
                            coordinator.createRichWorkspace(serverUrl: serverUrl, viewController: viewController, controller: controller, session: session)
                        }
                    }
                })
            }
        }

        // OFFICE - EDITOR
        //
        if isNetworkReachable, !isDirectoryE2EE {

            // COLLABORA: prefer Direct Editing and fall back to legacy Richdocuments.
            let collaboraCreators = creatorsByEditor[global.editorCollabora] ?? []
            let collaboraDocumentTypes: [(templateType: String, titleKey: String, icon: String, color: UIColor)] = [
                ("document", "_create_new_document_", "doc.richtext", NCBrandColor.shared.documentIconColor),
                ("spreadsheet", "_create_new_spreadsheet_", "tablecells", NCBrandColor.shared.spreadsheetIconColor),
                ("presentation", "_create_new_presentation_", "play.rectangle", NCBrandColor.shared.presentationIconColor),
                ("drawing", "_create_new_diagram_", "pencil.and.outline", NCBrandColor.shared.documentIconColor)
            ]

            for documentType in collaboraDocumentTypes {
                let directEditingCreator = collaboraCreators.first {
                    $0.identifier.lowercased() == documentType.templateType
                }
                guard directEditingCreator != nil || capabilities.richDocumentsEnabled else {
                    continue
                }

                menuRichDocumentElements.append(
                    UIAction(
                        title: NSLocalizedString(documentType.titleKey, comment: ""),
                        image: utility.loadImage(named: documentType.icon, colors: [documentType.color])
                    ) { _ in
                        Task { @MainActor in
                            if let directEditingCreator {
                                let createDocument = NCCreate()
                                let fileExt: String
                                let templateId: String
                                if directEditingCreator.templates {
                                    let result = await createDocument.getDirectEditingTemplates(
                                        editorId: directEditingCreator.editor,
                                        creatorId: directEditingCreator.identifier,
                                        fallbackExtension: directEditingCreator.ext,
                                        account: session.account
                                    )
                                    fileExt = result.ext
                                    templateId = result.selectedTemplate.identifier
                                } else {
                                    fileExt = directEditingCreator.ext
                                    templateId = ""
                                }

                                let fileName = await NCNetworking.shared.createFileName(
                                    fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + fileExt,
                                    account: session.account,
                                    serverUrl: serverUrl
                                )
                                await createDocument.createFileForDirectEditing(
                                    controller: controller,
                                    serverUrl: serverUrl,
                                    fileName: fileName,
                                    editorId: directEditingCreator.editor,
                                    creatorId: directEditingCreator.identifier,
                                    templateId: templateId,
                                    session: session
                                )
                            } else {
                                await self.createLegacyCollaboraFile(
                                    templateType: documentType.templateType,
                                    controller: controller,
                                    serverUrl: serverUrl,
                                    session: session
                                )
                            }
                        }
                    }
                )
            }

            if !menuRichDocumentElements.isEmpty {
                let collaboraTitle = capabilities.directEditingEditors.first {
                    $0.identifier.lowercased() == global.editorCollabora
                }?.name ?? "Collabora"
                officeEditorGroups.append((collaboraTitle, menuRichDocumentElements))
            }

            // EURO OFFICE - ONLY OFFICE
            //
            for editorId in [global.editorEuroOffice, global.editorOnlyOffice] {
                guard let editorCreators = creatorsByEditor[editorId],
                      NCDirectEditorAdapter.resolve(from: [editorId]) != nil else {
                    continue
                }

                let sortedCreators = editorCreators
                    .compactMap { creator -> (NKDirectEditingCreator, CreatorMenuInfo)? in
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
                                let result = await createDocument.getDirectEditingTemplates(
                                    editorId: editorId,
                                    creatorId: creator.identifier,
                                    fallbackExtension: creator.ext,
                                    account: session.account
                                )
                                fileExt = result.ext
                                templateIdentifier = result.selectedTemplate.identifier
                            } else {
                                fileExt = creator.ext
                                templateIdentifier = ""
                            }
                            let fileName = await NCNetworking.shared.createFileName(
                                fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + fileExt,
                                account: session.account,
                                serverUrl: serverUrl
                            )

                            await createDocument.createFileForDirectEditing(
                                controller: controller,
                                serverUrl: serverUrl,
                                fileName: fileName,
                                editorId: editorId,
                                creatorId: creator.identifier,
                                templateId: templateIdentifier,
                                session: session
                            )
                        }
                    }
                }

                guard !editorActions.isEmpty else {
                    continue
                }
                let editorTitle = capabilities.directEditingEditors.first {
                    $0.identifier.lowercased() == editorId
                }?.name ?? (editorId == global.editorOnlyOffice ? "ONLYOFFICE" : "EuroOffice")
                officeEditorGroups.append((editorTitle, editorActions))
            }

            // OTHERS
            //
            let filteredCreatorsByEditor = creatorsByEditor.filter {
                $0.key != global.editorEuroOffice &&
                $0.key != global.editorText &&
                $0.key != global.editorOnlyOffice &&
                $0.key != global.editorCollabora
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

                        await createDocument.createFileForDirectEditing(
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

            // NEXTCLOUD TEXT
            //
            if creatorsByEditor.keys.contains(global.editorText), let creator = creatorsByEditor[global.editorText]?.first {
                menuActionElements.append(UIAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""),
                                                   image: utility.loadImage(named: "text.document", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                    Task { @MainActor in
                        let fileName = await NCNetworking.shared.createFileName(
                            fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + creator.ext,
                            account: session.account,
                            serverUrl: serverUrl
                        )

                        await NCCreate().createFileForDirectEditing(
                            controller: controller,
                            serverUrl: serverUrl,
                            fileName: fileName,
                            editorId: creator.editor,
                            creatorId: creator.identifier,
                            templateId: "",
                            session: session)
                    }
                })
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

        // OFFICE EDITORS
        var menuOffice: UIMenu?
        if !officeEditorGroups.isEmpty || !menuDirectEditingOthersElements.isEmpty {
            var officeMenuElements: [UIMenuElement] = []

            if !menuDirectEditingOthersElements.isEmpty {
                let elements = orderedElementsForMenu(menuDirectEditingOthersElements)
                let menuDirectEditingOthers = UIMenu(
                    title: "",
                    options: .displayInline,
                    children: elements
                )
                menuDirectEditingOthers.preferredElementSize = menuDirectEditingOthersElements.count > 3 ? .automatic : .medium
                officeMenuElements.append(menuDirectEditingOthers)
            }

            if officeEditorGroups.count == 1, let editorGroup = officeEditorGroups.first {
                let actions = orderedElementsForMenu(editorGroup.actions)
                let editorActions = UIMenu(
                    title: "",
                    options: .displayInline,
                    children: actions
                )
                editorActions.preferredElementSize = editorGroup.actions.count > 3 ? .automatic : .medium
                officeMenuElements.append(editorActions)
            } else {
                officeMenuElements.append(contentsOf: officeEditorGroups.map { editorGroup in
                    UIMenu(
                        title: editorGroup.title,
                        image: UIImage(systemName: "doc.richtext"),
                        children: editorGroup.actions
                    )
                })
            }

            menuOffice = UIMenu(
                title: "Office",
                image: UIImage(systemName: "doc.richtext"),
                children: officeMenuElements
            )
        }

        // MENU PLUS
        var plusMenuElements: [UIMenuElement] = [menuAction, menuText]
        if let menuOffice {
            plusMenuElements.append(menuOffice)
        }
        plusMenuElements.append(menuFolder)

        let plusMenu = UIMenu(children: plusMenuElements)

        // PLUS BUTTON
        updatePlusButtonEnabled(session: session)

        if menuPlusButton.menu != nil,
           !capabilitiesChanged {
            return
        }

        menuPlusButton.menu = plusMenu
        menuPlusButton.showsMenuAsPrimaryAction = true
        menuPlusButton.alpha = 1
    }

    private func orderedElementsForMenu(_ elements: [UIMenuElement]) -> [UIMenuElement] {
        elements.count > 3 ? Array(elements.reversed()) : elements
    }

    private func makeCapabilitiesSignature(capabilities: NKCapabilities.Capabilities,
                                           account: String,
                                           serverUrl: String) -> String {
        let creators = capabilities.directEditingCreators
            .sorted { $0.identifier < $1.identifier }
            .map { "\($0.identifier)|\($0.editor)|\($0.ext)|\($0.mimetype)|\($0.templates)" }
            .joined(separator: ";")
        let editors = capabilities.directEditingEditors
            .sorted { $0.identifier < $1.identifier }
            .map { "\($0.identifier)|\($0.name)" }
            .joined(separator: ";")

        return "\(account)|\(serverUrl)|\(capabilities.richDocumentsEnabled)|\(creators)|\(editors)"
    }

    private func createLegacyCollaboraFile(templateType: String,
                                           controller: NCMainTabBarController,
                                           serverUrl: String,
                                           session: NCSession.Session) async {
        let createDocument = NCCreate()
        let result = await createDocument.getLegacyRichdocumentsTemplates(
            templateType: templateType,
            account: session.account
        )
        guard result.error == .success,
              let selectedTemplate = result.selectedTemplate else {
            await showErrorBanner(
                windowScene: windowScene,
                text: result.error.errorDescription,
                errorCode: result.error.errorCode
            )
            return
        }

        let fileName = await NCNetworking.shared.createFileName(
            fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + result.ext,
            account: session.account,
            serverUrl: serverUrl
        )
        await createDocument.createLegacyRichdocumentsFile(
            controller: controller,
            serverUrl: serverUrl,
            fileName: fileName,
            templateId: String(selectedTemplate.templateId),
            session: session
        )
    }

    func updatePlusButtonEnabled(session: NCSession.Session) {
        guard let controller, let menuPlusButton else {
            return
        }

        let isEnabled = isPlusButtonEnabled(for: controller)

        menuPlusButton.isEnabled = isEnabled
        menuPlusButton.setPlusButtonColor(isEnabled ? NCBrandColor.shared.getElement(account: session.account) : .lightGray)
    }

    private func isPlusButtonEnabled(for controller: NCMainTabBarController) -> Bool {
        guard let viewController = controller.currentViewController() as? NCCollectionViewCommon,
              let metadataFolder = viewController.metadataFolder else {
            return true
        }

        guard !viewController.endToEndKeySetAccess.isReadOnly else {
            return false
        }

        guard metadataFolder.isCreatable else {
            return false
        }

        guard metadataFolder.e2eEncrypted else {
            return true
        }

        return NextcloudKit.shared.isNetworkReachable()
    }

    @MainActor
    func hiddenPlusButton(isEditMode: Bool, isSearchingMode: Bool, animation: Bool = true) {
        if isEditMode || isSearchingMode {
            hiddenPlusButton(true, animation: animation)
        } else {
            hiddenPlusButton(false, animation: animation)
        }
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
        switch documentType {
        case "spreadsheet": return NCBrandColor.shared.spreadsheetIconColor
        case "presentation": return NCBrandColor.shared.presentationIconColor
        default: return NCBrandColor.shared.documentIconColor
        }
    }
}
