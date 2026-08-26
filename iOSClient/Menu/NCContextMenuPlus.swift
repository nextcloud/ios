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
    private var menuSignature: String?

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
        let isEndToEndEnabled = NCPreferences().isEndToEndEnabled(account: session.account)
        let titleCreateFolder = isDirectoryE2EE ? NSLocalizedString("_create_folder_e2ee_", comment: "") : NSLocalizedString("_create_folder_", comment: "")
        let imageCreateFolder = isDirectoryE2EE ? NCImageCache.shared.getFolderEncrypted(account: session.account) : NCImageCache.shared.getFolder(account: session.account)
        let creatorsByEditor = Dictionary(grouping: capabilities.directEditingCreators, by: \.editor)
        let currentMenuSignature = makeMenuSignature(capabilities: capabilities, account: session.account,
                                                     serverUrl: serverUrl, isEndToEndEnabled: isEndToEndEnabled)
        let menuChanged = menuSignature != currentMenuSignature
        menuSignature = currentMenuSignature

        var menuUploadElements: [UIMenuElement] = []
        var menuCaptureElements: [UIMenuElement] = []
        var menuFolderElements: [UIMenuElement] = []
        var menuTextElements: [UIMenuElement] = []
        var menuDirectEditingOthersElements: [UIMenuElement] = []
        var menuNextcloudTextAction: UIAction?
        var officeEditorGroups: [(editorId: String, title: String, standardActions: [UIMenuElement], additionalActions: [UIMenuElement])] = []

        // ACTION
        //
        menuUploadElements.append(UIAction(title: NSLocalizedString("_upload_photos_videos_", comment: ""),
                                           image: utility.loadImage(named: "photo", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
                if hasPermission {
                    DispatchQueue.main.async {
                        NCPhotosPickerViewController(controller: controller, maxSelectedAssets: 0, singleSelectedMode: false)
                    }
                }
            }
        })

        menuUploadElements.append(UIAction(title: NSLocalizedString("_upload_file_", comment: ""),
                                           image: utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            DispatchQueue.main.async {
                controller.documentPickerViewController = NCDocumentPickerViewController(controller: controller, isViewerMedia: false, allowsMultipleSelection: true)
            }
        })

        menuCaptureElements.append(UIAction(title: NSLocalizedString("_scans_document_", comment: ""),
                                           image: utility.loadImage(named: "doc.text.viewfinder", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            DispatchQueue.main.async {
                NCDocumentCamera.shared.openScannerDocument(viewController: controller)
            }
        })

        menuCaptureElements.append(UIAction(title: NSLocalizedString("_create_voice_memo_", comment: ""),
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
           isEndToEndEnabled,
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
            var collaboraStandardActions: [UIMenuElement] = []
            var collaboraAdditionalActions: [UIMenuElement] = []

            for documentType in collaboraDocumentTypes {
                let directEditingCreator = collaboraCreators.first {
                    $0.identifier.lowercased() == documentType.templateType
                }
                guard directEditingCreator != nil || capabilities.richDocumentsEnabled else {
                    continue
                }

                let action = UIAction(
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

                if documentType.templateType == "drawing" {
                    collaboraAdditionalActions.append(action)
                } else {
                    collaboraStandardActions.append(action)
                }
            }

            if !collaboraStandardActions.isEmpty || !collaboraAdditionalActions.isEmpty {
                let collaboraTitle = capabilities.directEditingEditors.first {
                    $0.identifier.lowercased() == global.editorCollabora
                }?.name ?? "Collabora"
                officeEditorGroups.append((global.editorCollabora, collaboraTitle, collaboraStandardActions, collaboraAdditionalActions))
            }

            // EURO OFFICE - ONLY OFFICE
            //
            for editorId in [global.editorEuroOffice, global.editorOnlyOffice] {
                guard let editorCreators = creatorsByEditor[editorId],
                      NCDirectEditorAdapter.resolve(from: [editorId]) != nil else {
                    continue
                }

                let sortedCreators = editorCreators.sorted { lhs, rhs in
                    let lhsOrder = NCContextMenuPlus.menuInfo(for: lhs.ext)?.sortOrder ?? Int.max
                    let rhsOrder = NCContextMenuPlus.menuInfo(for: rhs.ext)?.sortOrder ?? Int.max
                    if lhsOrder == rhsOrder {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    return lhsOrder < rhsOrder
                }
                var standardActions: [UIMenuElement] = []
                var additionalActions: [UIMenuElement] = []

                for creator in sortedCreators {
                    let info = NCContextMenuPlus.menuInfo(for: creator.ext)
                    let action = makeDirectEditingAction(
                        creator: creator,
                        title: info.map { NSLocalizedString($0.titleKey, comment: "") } ?? creator.name,
                        image: info.map {
                            utility.loadImage(named: $0.icon, colors: [$0.iconColor])
                        } ?? UIImage(systemName: "doc"),
                        controller: controller,
                        serverUrl: serverUrl,
                        session: session
                    )

                    if info == nil {
                        additionalActions.append(action)
                    } else {
                        standardActions.append(action)
                    }
                }

                guard !standardActions.isEmpty || !additionalActions.isEmpty else {
                    continue
                }
                let editorTitle = capabilities.directEditingEditors.first {
                    $0.identifier.lowercased() == editorId
                }?.name ?? (editorId == global.editorOnlyOffice ? "ONLYOFFICE" : "EuroOffice")
                officeEditorGroups.append((editorId, editorTitle, standardActions, additionalActions))
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

                let action = makeDirectEditingAction(
                    creator: creator,
                    title: creator.name,
                    image: image,
                    controller: controller,
                    serverUrl: serverUrl,
                    session: session,
                    useTemplates: false
                )

                menuDirectEditingOthersElements.append(action)
            }

            // NEXTCLOUD TEXT
            //
            if creatorsByEditor.keys.contains(global.editorText), let creator = creatorsByEditor[global.editorText]?.first {
                menuNextcloudTextAction = UIAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""),
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
                }
            }
        }

        // UPLOAD
        let menuUpload = UIMenu(title: "", options: .displayInline, children: menuUploadElements)

        // CAPTURE
        let menuCapture = UIMenu(title: "", options: .displayInline, children: menuCaptureElements)

        // FOLDER
        let menuFolder = makeFolderMenu(elements: menuFolderElements)

        // OFFICE EDITORS
        var menuStandardDocuments: UIMenu?
        var menuMoreDocuments: UIMenu?
        if !officeEditorGroups.isEmpty || !menuDirectEditingOthersElements.isEmpty {
            let officeEditorPriority = [global.editorEuroOffice, global.editorCollabora, global.editorOnlyOffice]
            let primaryOfficeIndex = officeEditorPriority.lazy.compactMap { editorId in
                officeEditorGroups.firstIndex {
                    $0.editorId == editorId && !$0.standardActions.isEmpty
                }
            }.first ?? officeEditorGroups.firstIndex { !$0.standardActions.isEmpty }

            if let primaryOfficeIndex {
                let primaryOffice = officeEditorGroups[primaryOfficeIndex]
                menuStandardDocuments = UIMenu(
                    title: "",
                    options: .displayInline,
                    children: primaryOffice.standardActions
                )
                menuStandardDocuments?.preferredElementSize = .medium
            }

            var moreDocumentsElements: [UIMenuElement] = []
            var additionalDocumentActions = menuDirectEditingOthersElements
            if let primaryOfficeIndex {
                additionalDocumentActions.insert(
                    contentsOf: officeEditorGroups[primaryOfficeIndex].additionalActions,
                    at: 0
                )
            }

            let secondaryOfficeMenus = makeSecondaryOfficeMenus(
                officeEditorGroups: officeEditorGroups,
                primaryOfficeIndex: primaryOfficeIndex
            )

            let hasMoreDocuments = !additionalDocumentActions.isEmpty || !secondaryOfficeMenus.isEmpty
            if hasMoreDocuments, let menuNextcloudTextAction {
                additionalDocumentActions.append(menuNextcloudTextAction)
            }

            if !additionalDocumentActions.isEmpty {
                let additionalDocumentsMenu = UIMenu(
                    title: "",
                    options: .displayInline,
                    children: orderedElementsForMenu(additionalDocumentActions)
                )
                moreDocumentsElements.append(additionalDocumentsMenu)
            }

            moreDocumentsElements.append(contentsOf: secondaryOfficeMenus)

            if !moreDocumentsElements.isEmpty {
                menuMoreDocuments = UIMenu(
                    title: NSLocalizedString("_more_documents_", comment: ""),
                    image: UIImage(systemName: "doc.badge.plus"),
                    children: moreDocumentsElements
                )
            }
        }

        if menuMoreDocuments == nil, let menuNextcloudTextAction {
            menuTextElements.append(menuNextcloudTextAction)
        }
        let menuText = UIMenu(title: "", options: .displayInline, children: Array(menuTextElements.reversed()))

        // MENU PLUS
        var plusMenuElements: [UIMenuElement] = []
        if let menuStandardDocuments {
            plusMenuElements.append(menuStandardDocuments)
        }
        if let menuMoreDocuments {
            plusMenuElements.append(menuMoreDocuments)
        }
        plusMenuElements.append(menuFolder)
        if !menuTextElements.isEmpty {
            plusMenuElements.append(menuText)
        }
        plusMenuElements.append(contentsOf: [menuUpload, menuCapture])

        let plusMenu = UIMenu(children: Array(plusMenuElements.reversed()))

        // PLUS BUTTON
        updatePlusButtonEnabled(session: session)

        if menuPlusButton.menu != nil,
           !menuChanged {
            return
        }

        menuPlusButton.menu = plusMenu
        menuPlusButton.showsMenuAsPrimaryAction = true
        menuPlusButton.alpha = 1
    }

    private func makeFolderMenu(elements: [UIMenuElement]) -> UIMenu {
        let children = elements.count > 1 ? elements : Array(elements.reversed())
        let menu = UIMenu(title: "", options: .displayInline, children: children)
        if elements.count > 1 {
            menu.preferredElementSize = .automatic
        }
        return menu
    }

    private func makeSecondaryOfficeMenus(
        officeEditorGroups: [(editorId: String, title: String, standardActions: [UIMenuElement], additionalActions: [UIMenuElement])],
        primaryOfficeIndex: Int?
    ) -> [UIMenuElement] {
        officeEditorGroups.enumerated().compactMap { index, editorGroup in
            guard index != primaryOfficeIndex else {
                return nil
            }
            return UIMenu(
                title: editorGroup.title,
                image: UIImage(systemName: "doc.richtext"),
                children: editorGroup.standardActions + editorGroup.additionalActions
            )
        }
    }

    private func orderedElementsForMenu(_ elements: [UIMenuElement]) -> [UIMenuElement] {
        elements.count > 3 ? Array(elements.reversed()) : elements
    }

    private func makeDirectEditingAction(creator: NKDirectEditingCreator,
                                         title: String,
                                         image: UIImage?,
                                         controller: NCMainTabBarController,
                                         serverUrl: String,
                                         session: NCSession.Session,
                                         useTemplates: Bool = true) -> UIAction {
        UIAction(title: title, image: image) { _ in
            Task { @MainActor in
                let createDocument = NCCreate()
                let fileExt: String
                let templateIdentifier: String
                if useTemplates, creator.templates {
                    let result = await createDocument.getDirectEditingTemplates(
                        editorId: creator.editor,
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
                    editorId: creator.editor,
                    creatorId: creator.identifier,
                    templateId: templateIdentifier,
                    session: session
                )
            }
        }
    }

    private func makeMenuSignature(capabilities: NKCapabilities.Capabilities,
                                   account: String,
                                   serverUrl: String,
                                   isEndToEndEnabled: Bool) -> String {
        let creators = capabilities.directEditingCreators
            .sorted { $0.identifier < $1.identifier }
            .map { "\($0.identifier)|\($0.editor)|\($0.ext)|\($0.mimetype)|\($0.templates)" }
            .joined(separator: ";")
        let editors = capabilities.directEditingEditors
            .sorted { $0.identifier < $1.identifier }
            .map { "\($0.identifier)|\($0.name)" }
            .joined(separator: ";")

        return "\(account)|\(serverUrl)|\(isEndToEndEnabled)|\(capabilities.richDocumentsEnabled)|\(creators)|\(editors)"
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

        guard metadataFolder.isCreatable else {
            return false
        }

        guard metadataFolder.e2eEncrypted else {
            return true
        }

        guard viewController.endToEndKeySetAccess.canWrite else {
            return false
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
