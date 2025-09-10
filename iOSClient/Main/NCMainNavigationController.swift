// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

class NCMainNavigationController: UINavigationController, UINavigationControllerDelegate {
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    let utility = NCUtility()
    let utilityFileSystem = NCUtilityFileSystem()
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    var plusItem: UIBarButtonItem?
    var plusMenu = UIMenu()
    let menuToolbar = UIToolbar()

    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    var collectionViewCommon: NCCollectionViewCommon? {
        topViewController as? NCCollectionViewCommon
    }

    var trashViewController: NCTrash? {
        topViewController as? NCTrash
    }

    var mediaViewController: NCMedia? {
        topViewController as? NCMedia
    }

    @MainActor
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    let menuButtonTag = 100
    let assistantButtonTag = 101
    let notificationsButtonTag = 102
    let transfersButtonTag = 103

    lazy var menuButton: UIButton = {
        let button = UIButton(type: .system)
        return button
    }()
    var menuBarButtonItem: UIBarButtonItem {
        let item = UIBarButtonItem(customView: menuButton)
        item.tag = menuButtonTag
        return item
    }
    lazy var assistantButton: UIButton = {
        let button = UIButton(type: .system)
        return button
    }()
    var assistantButtonItem: UIBarButtonItem {
        let item = UIBarButtonItem(customView: assistantButton)
        item.tag = assistantButtonTag
        return item
    }

    lazy var notificationsButton: UIButton = {
        let button = UIButton(type: .system)
        return button
    }()
    var notificationsButtonItem: UIBarButtonItem {
        let item = UIBarButtonItem(customView: notificationsButton)
        item.tag = notificationsButtonTag
        return item
    }

    lazy var transfersButton: UIButton = {
        let button = UIButton(type: .system)
        return button
    }()
    var transfersButtonItem: UIBarButtonItem {
        let item = UIBarButtonItem(customView: transfersButton)
        item.tag = transfersButtonTag
        return item
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self

        setNavigationBarAppearance()
        setNavigationBarHidden(false, animated: true)

        Task {
            menuButton.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
            menuButton.tintColor = NCBrandColor.shared.iconImageColor
            menuButton.menu = await createRightMenu()
            menuButton.showsMenuAsPrimaryAction = true
        }

        assistantButton.setImage(UIImage(systemName: "sparkles"), for: .normal)
        assistantButton.tintColor = NCBrandColor.shared.iconImageColor
        assistantButton.addAction(UIAction(handler: { _ in
            let assistant = NCAssistant()
                .environmentObject(NCAssistantModel(controller: self.controller))
            let hostingController = UIHostingController(rootView: assistant)
            self.present(hostingController, animated: true, completion: nil)
        }), for: .touchUpInside)

        notificationsButton.setImage(UIImage(systemName: "bell.fill"), for: .normal)
        notificationsButton.tintColor = NCBrandColor.shared.iconImageColor
        notificationsButton.addAction(UIAction(handler: { _ in
            if let navigationController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? UINavigationController,
               let viewController = navigationController.topViewController as? NCNotification {
                viewController.modalPresentationStyle = .pageSheet
                viewController.session = self.session
                self.present(navigationController, animated: true, completion: nil)
            }
        }), for: .touchUpInside)

        transfersButton.setImage(UIImage(systemName: "arrow.left.arrow.right.circle.fill"), for: .normal)
        transfersButton.tintColor = NCBrandColor.shared.iconImageColor
        transfersButton.addAction(UIAction(handler: { _ in
            if let navigationController = UIStoryboard(name: "NCTransfers", bundle: nil).instantiateInitialViewController() as? UINavigationController,
               let viewController = navigationController.topViewController as? NCTransfers {
                viewController.modalPresentationStyle = .pageSheet
                self.present(navigationController, animated: true, completion: nil)
            }
        }), for: .touchUpInside)

        // PLUS BUTTON ONLY IN FILES
        if topViewController is NCFiles {
            let widthAnchor: CGFloat
            let trailingAnchor: CGFloat
            let trailingAnchorPad: CGFloat

            if #available(iOS 26.0, *) {
                widthAnchor = 44
                trailingAnchor = -15
                trailingAnchorPad = -20
            } else {
                let appearance = UIToolbarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.backgroundColor = .clear
                appearance.backgroundEffect = nil
                appearance.shadowColor = .clear

                menuToolbar.standardAppearance = appearance
                menuToolbar.compactAppearance  = appearance
                menuToolbar.scrollEdgeAppearance = appearance
                menuToolbar.isTranslucent = true

                widthAnchor = 100
                trailingAnchor = 28
                trailingAnchorPad = -10
            }

            view.addSubview(menuToolbar)
            menuToolbar.translatesAutoresizingMaskIntoConstraints = false

            if UIDevice.current.userInterfaceIdiom == .pad {
                NSLayoutConstraint.activate([
                    menuToolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: trailingAnchorPad),
                    menuToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                    menuToolbar.widthAnchor.constraint(equalToConstant: widthAnchor)
                ])
            } else {
                NSLayoutConstraint.activate([
                    menuToolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: trailingAnchor),
                    menuToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
                    menuToolbar.widthAnchor.constraint(equalToConstant: widthAnchor)
                ])
            }

            let config = UIImage.SymbolConfiguration(pointSize: 25, weight: .thin)
            let plusImage = UIImage(systemName: "plus.circle.fill", withConfiguration: config)

            plusItem = UIBarButtonItem(image: plusImage, style: .plain, target: nil, action: nil)
            plusItem?.tintColor = NCBrandColor.shared.customer
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: self.global.notificationCenterServerDidUpdate), object: nil, queue: nil) { notification in
            guard let userInfo = notification.userInfo,
                  let account = userInfo["account"] as? String else {
                return
            }

            Task { @MainActor in
                let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
                guard capabilities.notification.count > 0 else {
                    if self.isNotificationsButtonVisible() {
                        self.controller?.availableNotifications = false
                        await self.updateRightBarButtonItems()
                    }
                    return
                }

                // Notification
                let resultsNotification = await NextcloudKit.shared.getNotificationsAsync(account: account) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                    name: "getNotifications")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                }
                if resultsNotification.error == .success,
                    let notifications = resultsNotification.notifications,
                    notifications.count > 0 {
                    if !self.isNotificationsButtonVisible() {
                        self.controller?.availableNotifications = true
                        await self.updateRightBarButtonItems()
                    }
                } else {
                    if self.isNotificationsButtonVisible() {
                        self.controller?.availableNotifications = false
                        await self.updateRightBarButtonItems()
                    }
                }

                // Menu Plus
                let session = NCSession.shared.getSession(account: account)
                self.createPlusMenu(session: session, capabilities: capabilities)
            }
        }
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        Task { @MainActor in
            // MENU
            setNavigationBarAppearance()
            await updateRightBarButtonItems()
        }
    }

    // MARK: - PLUS

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
                let alertController = UIAlertController.createFolder(serverUrl: serverUrl, session: session, sceneIdentifier: controller.sceneIdentifier, capabilities: capabilities)
                controller.present(alertController, animated: true, completion: nil)
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

        plusMenu = UIMenu(children: [menuAction, menuE2EE, menuText, menuRichDocument, menuOnlyOffice])
        plusItem.menu = plusMenu
        menuToolbar.setItems([plusItem], animated: false)
        menuToolbar.sizeToFit()
        menuToolbar.alpha = 1
    }

    func isHiddenPlusButton(_ isHidden: Bool, animation: Bool = true) {
        if isHidden {
            if animation {
                UIView.animate(withDuration: 0.5, delay: 0.0, options: [], animations: {
                    self.menuToolbar.transform = CGAffineTransform(translationX: 100, y: 0)
                    self.menuToolbar.alpha = 0
                })
            } else {
                self.menuToolbar.alpha = 0
            }
        } else {
            if animation {
                self.menuToolbar.transform = CGAffineTransform(translationX: 100, y: 0)
                self.menuToolbar.alpha = 0

                UIView.animate(withDuration: 0.5, delay: 0.3, options: [], animations: {
                    self.menuToolbar.transform = .identity
                    self.menuToolbar.alpha = 1
                })
            } else {
                self.menuToolbar.alpha = 1
            }
        }
    }

    func resetPlusButtonAlpha(animated: Bool = true) {
        let update = {
            self.menuToolbar.alpha = 1.0
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: update)
        } else {
            update()
        }
    }

    // MARK: - Right

    func setNavigationRightItems() async {
        if let collectionViewCommon, collectionViewCommon.isEditMode {
            collectionViewCommon.tabBarSelect?.update(fileSelect: collectionViewCommon.fileSelect,
                                                      metadatas: collectionViewCommon.getSelectedMetadatas(),
                                                      userId: session.userId)
            collectionViewCommon.tabBarSelect?.show()

            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .plain) {
                collectionViewCommon.setEditMode(false)
            }

            collectionViewCommon.navigationItem.rightBarButtonItems = [select]

        } else if let trashViewController, trashViewController.isEditMode {
            trashViewController.tabBarSelect.update(selectOcId: [])
            trashViewController.tabBarSelect.show()

            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .plain) {
                trashViewController.setEditMode(false)
            }

            trashViewController.navigationItem.rightBarButtonItems = [select]

        } else {
            trashViewController?.tabBarSelect?.hide()
            collectionViewCommon?.tabBarSelect?.hide()
            await self.updateRightBarButtonItems()
        }
    }

    @discardableResult
    @MainActor
    func updateRightBarButtonItems(_ fileItem: UITabBarItem? = nil) async -> Int {
        guard !(collectionViewCommon?.isEditMode ?? false),
              !(trashViewController?.isEditMode ?? false),
              !(mediaViewController?.isEditMode ?? false),
              !(topViewController is NCViewerMediaPage),
              !(topViewController is NCViewerPDF),
              !(topViewController is NCViewerRichDocument),
              !(topViewController is NCViewerNextcloudText)
        else {
            return 0
        }

        let transferCount = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "status != %i", self.global.metadataStatusNormal))?.count ?? 0
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        let rightmenu = await createRightMenu()
        var tempRightBarButtonItems: [UIBarButtonItem] = rightmenu == nil ? [] : [self.menuBarButtonItem]
        var tempTotalTags = tempRightBarButtonItems.count == 0 ? 0 : self.menuBarButtonItem.tag
        var totalTags = 0

        if let rightBarButtonItems = topViewController?.navigationItem.rightBarButtonItems {
            for item in rightBarButtonItems {
                totalTags += item.tag
            }
        }

        if capabilities.assistantEnabled {
            tempRightBarButtonItems.append(self.assistantButtonItem)
            tempTotalTags += self.assistantButtonItem.tag
        }

        if let controller, controller.availableNotifications {
            tempRightBarButtonItems.append(self.notificationsButtonItem)
            tempTotalTags += self.notificationsButtonItem.tag
        }

        if transferCount > 0 {
            tempRightBarButtonItems.append(self.transfersButtonItem)
            tempTotalTags += self.transfersButtonItem.tag
        }

        if totalTags != tempTotalTags {
            topViewController?.navigationItem.rightBarButtonItems = tempRightBarButtonItems
        }

        // Update App Icon badge / File Icon badge
#if DEBUG
        try? await UNUserNotificationCenter.current().setBadgeCount(transferCount)
        fileItem?.badgeValue = transferCount == 0 ? nil : "\(transferCount)"
#else
        if transferCount > 999 {
            try? await UNUserNotificationCenter.current().setBadgeCount(999)
            fileItem?.badgeValue = "999+"
        } else {
            try? await UNUserNotificationCenter.current().setBadgeCount(transferCount)
            fileItem?.badgeValue = transferCount == 0 ? nil : "\(transferCount)"
        }
#endif

        return transferCount
    }

    func createRightMenu() async -> UIMenu? { return nil }

    func updateRightMenu() async {
        if let rightBarButtonItems = topViewController?.navigationItem.rightBarButtonItems,
            let menuBarButtonItem = rightBarButtonItems.first(where: { $0.tag == menuButtonTag }),
            let menuButton = menuBarButtonItem.customView as? UIButton {
            menuButton.menu = await createRightMenu()
        }
    }

    func createRightMenuActions() async -> (select: UIAction,
                                            viewStyleSubmenu: UIMenu,
                                            sortSubmenu: UIMenu,
                                            favoriteOnTop: UIAction,
                                            directoryOnTop: UIAction,
                                            hiddenFiles: UIAction,
                                            personalFilesOnly: UIAction,
                                            showDescription: UIAction,
                                            showRecommendedFiles: UIAction?)? {
        guard let collectionViewCommon else {
            return nil
        }
        var showRecommendedFiles: UIAction?
        let layoutForView = database.getLayoutForView(account: session.account, key: collectionViewCommon.layoutKey, serverUrl: collectionViewCommon.serverUrl)
        let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                              image: utility.loadImage(named: "checkmark.circle")) { _ in
            if !collectionViewCommon.dataSource.isEmpty() {
                collectionViewCommon.setEditMode(true)
                collectionViewCommon.collectionView.reloadData()
            }
        }

        let list = UIAction(title: NSLocalizedString("_list_", comment: ""),
                            image: utility.loadImage(named: "list.bullet"),
                            state: layoutForView.layout == global.layoutList ? .on : .off) { _ in
            Task {
                layoutForView.layout = self.global.layoutList
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""),
                            image: utility.loadImage(named: "square.grid.2x2"),
                            state: layoutForView.layout == global.layoutGrid ? .on : .off) { _ in
            Task {
                layoutForView.layout = self.global.layoutGrid
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let mediaSquare = UIAction(title: NSLocalizedString("_media_square_", comment: ""),
                                   image: utility.loadImage(named: "square.grid.3x3"),
                                   state: layoutForView.layout == global.layoutPhotoSquare ? .on : .off) { _ in
            Task {
                layoutForView.layout = self.global.layoutPhotoSquare
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let mediaRatio = UIAction(title: NSLocalizedString("_media_ratio_", comment: ""),
                                  image: utility.loadImage(named: "rectangle.grid.3x2"),
                                  state: layoutForView.layout == self.global.layoutPhotoRatio ? .on : .off) { _ in
            Task {
                layoutForView.layout = self.global.layoutPhotoRatio
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid, mediaSquare, mediaRatio])

        let ascending = layoutForView.ascending
        let ascendingChevronImage = utility.loadImage(named: ascending ? "chevron.up" : "chevron.down")
        let isName = layoutForView.sort == "fileName"
        let isDate = layoutForView.sort == "date"
        let isSize = layoutForView.sort == "size"

        let byName = UIAction(title: NSLocalizedString("_name_", comment: ""),
                              image: isName ? ascendingChevronImage : nil,
                              state: isName ? .on : .off) { _ in
            Task {
                if isName {
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "fileName"
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""),
                                image: isDate ? ascendingChevronImage : nil,
                                state: isDate ? .on : .off) { _ in
            Task {
                if isDate {
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "date"
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""),
                                 image: isSize ? ascendingChevronImage : nil,
                                 state: isSize ? .on : .off) { _ in
            Task {
                if isSize {
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "size"
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""),
                                 options: .displayInline,
                                 children: [byName, byNewest, byLargest])

        let favoriteOnTop = NCPreferences().getFavoriteOnTop(account: self.session.account)
        let favoriteOnTopAction = UIAction(title: NSLocalizedString("_favorite_on_top_", comment: ""),
                                           state: favoriteOnTop ? .on : .off) { _ in
            Task {
                NCPreferences().setFavoriteOnTop(account: self.session.account, value: !favoriteOnTop)
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: collectionViewCommon.serverUrl, status: nil)
                }
                await self.updateRightMenu()
            }
        }

        let directoryOnTop = NCPreferences().getDirectoryOnTop(account: self.session.account)
        let directoryOnTopAction = UIAction(title: NSLocalizedString("_directory_on_top_", comment: ""),
                                            state: directoryOnTop ? .on : .off) { _ in
            Task {
                NCPreferences().setDirectoryOnTop(account: self.session.account, value: !directoryOnTop)
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: collectionViewCommon.serverUrl, status: nil)
                }
                await self.updateRightMenu()
            }
        }

        let hiddenFiles = NCPreferences().getShowHiddenFiles(account: self.session.account)
        let hiddenFilesAction = UIAction(title: NSLocalizedString("_show_hidden_files_", comment: ""),
                                         state: hiddenFiles ? .on : .off) { _ in
            Task {
                NCPreferences().setShowHiddenFiles(account: self.session.account, value: !hiddenFiles)
                await self.collectionViewCommon?.getServerData(forced: true)
                await self.updateRightMenu()
            }
        }

        let personalFilesOnly = NCPreferences().getPersonalFilesOnly(account: self.session.account)
        let personalFilesOnlyAction = UIAction(title: NSLocalizedString("_personal_files_only_", comment: ""),
                                               image: utility.loadImage(named: "folder.badge.person.crop", colors: NCBrandColor.shared.iconImageMultiColors),
                                               state: personalFilesOnly ? .on : .off) { _ in
            Task {
                NCPreferences().setPersonalFilesOnly(account: self.session.account, value: !personalFilesOnly)
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: collectionViewCommon.serverUrl, status: nil)
                }
                await self.updateRightMenu()
            }
        }

        let showDescriptionKeychain = NCPreferences().showDescription
        let showDescription = UIAction(title: NSLocalizedString("_show_description_", comment: ""),
                                       state: showDescriptionKeychain ? .on : .off) { _ in
            NCPreferences().showDescription = !showDescriptionKeychain
            Task {
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: collectionViewCommon.serverUrl, status: nil)
                }
                await self.updateRightMenu()
            }
        }

        let showRecommendedFilesKeychain = NCPreferences().showRecommendedFiles
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
        let capabilityRecommendations = capabilities.recommendations

        if capabilityRecommendations {
            showRecommendedFiles = UIAction(title: NSLocalizedString("_show_recommended_files_", comment: ""),
                                            state: showRecommendedFilesKeychain ? .on : .off) { _ in
                Task {
                    NCPreferences().showRecommendedFiles = !showRecommendedFilesKeychain
                    collectionViewCommon.collectionView.reloadData()
                    await self.updateRightMenu()
                }
            }
        }

        return (select, viewStyleSubmenu, sortSubmenu, favoriteOnTopAction, directoryOnTopAction, hiddenFilesAction, personalFilesOnlyAction, showDescription, showRecommendedFiles)
    }

    func createTrashRightMenuActions() async -> [UIMenuElement]? {
        guard let trashViewController else {
            return nil
        }
        let layoutForView = self.database.getLayoutForView(account: session.account, key: trashViewController.layoutKey, serverUrl: "")

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                              image: utility.loadImage(named: "checkmark.circle")) { _ in
            if let datasource = trashViewController.datasource,
               !datasource.isEmpty {
                trashViewController.setEditMode(true)
                trashViewController.collectionView.reloadData()
            }
        }
        let list = UIAction(title: NSLocalizedString("_list_", comment: ""),
                            image: utility.loadImage(named: "list.bullet", colors: [NCBrandColor.shared.iconImageColor]),
                            state: layoutForView.layout == self.global.layoutList ? .on : .off) { _ in
            Task {
                trashViewController.onListSelected()
                await self.updateRightMenu()
            }
        }
        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""),
                            image: utility.loadImage(named: "square.grid.2x2", colors: [NCBrandColor.shared.iconImageColor]),
                            state: layoutForView.layout == self.global.layoutGrid ? .on : .off) { _ in
            Task {
                trashViewController.onGridSelected()
                await self.updateRightMenu()
            }
        }

        let emptyTrash = UIAction(title: NSLocalizedString("_empty_trash_", comment: ""),
                                  image: utility.loadImage(named: "trash", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            Task {
                await trashViewController.emptyTrash()
            }
        }

        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid])

        return [select, viewStyleSubmenu, emptyTrash]
    }

    func isNotificationsButtonVisible() -> Bool {
        if topViewController?.navigationItem.rightBarButtonItems?.first(where: { $0.tag == notificationsButtonTag }) != nil {
            return true
        }
        return false
    }

    func isTransfersButtonVisible() -> Bool {
        if topViewController?.navigationItem.rightBarButtonItems?.first(where: { $0.tag == transfersButtonTag }) != nil {
            return true
        }
        return false
    }

    /// Changes the tint color of a specific right bar button item identified by tag.
    /// - Parameters:
    ///   - tag: The tag used to identify the UIBarButtonItem.
    ///   - color: The UIColor to be applied.
    @MainActor
    func setRightItemColor(tag: Int, to color: UIColor) {
        guard
            let items = topViewController?.navigationItem.rightBarButtonItems,
            let item = items.first(where: { $0.tag == tag }),
            let button = item.customView as? UIButton
        else { return }

        applyTint(button, color: color)
    }

    /// Changes the tint color of all right bar button items currently visible
    /// in the topViewController's navigation item.
    /// - Parameter color: The UIColor to be applied.
    @MainActor
    func setAllRightItemsColor(_ color: UIColor) {
        guard let items = topViewController?.navigationItem.rightBarButtonItems else { return }

        for item in items {
            if let button = item.customView as? UIButton {
                applyTint(button, color: color)
            }
        }
    }

    // MARK: - Left

    func setNavigationLeftItems() async { }

    /// Changes the tint color of a specific left bar button item identified by tag.
    /// - Parameters:
    ///   - tag: The tag used to identify the UIBarButtonItem.
    ///   - color: The UIColor to be applied.
    @MainActor
    func setLeftItemColor(tag: Int, to color: UIColor) {
        guard
            let items = topViewController?.navigationItem.leftBarButtonItems,
            let item = items.first(where: { $0.tag == tag }),
            let button = item.customView as? UIButton
        else { return }

        applyTint(button, color: color)
    }

    /// Changes the tint color of all left bar button items currently visible
    /// in the topViewController's navigation item.
    /// - Parameter color: The UIColor to be applied.
    @MainActor
    func setAllLeftItemsColor(_ color: UIColor) {
        guard let items = topViewController?.navigationItem.leftBarButtonItems else { return }

        for item in items {
            if let button = item.customView as? UIButton {
                applyTint(button, color: color)
            }
        }
    }

    // MARK: - Tint helpers

    /// Applies a tint color to a given UIButton, handling both UIButton.Configuration
    /// and legacy setup with SF Symbols or titles.
    /// - Parameters:
    ///   - button: The UIButton to apply the color.
    ///   - color: The UIColor to be applied.
    @MainActor
    private func applyTint(_ button: UIButton, color: UIColor) {
        if var cfg = button.configuration {
            // Se in futuro userai UIButton.Configuration, tieni il colore allineato qui
            cfg.baseForegroundColor = color
            button.configuration = cfg
        } else {
            // Config attuale (nessuna configuration): SF Symbols sono template, quindi basta tintColor
            button.tintColor = color
            button.setTitleColor(color, for: .normal)
        }
    }

    /// Updates the tint color of all preloaded and currently visible right bar buttons.
    /// - Parameter color: The UIColor to be applied to all right bar button items.
    @MainActor
    func updateRightBarButtonsTint(to color: UIColor) {
        let rightButtons: [UIButton] = [
            menuButton,
            assistantButton,
            notificationsButton,
            transfersButton
        ]

        // Apply color to preloaded button instances
        for button in rightButtons {
            if var cfg = button.configuration {
                cfg.baseForegroundColor = color
                button.configuration = cfg
            } else {
                button.tintColor = color
                button.setTitleColor(color, for: .normal)
            }
        }

        // Update also those already visible in the navigation bar
        if let rightItems = topViewController?.navigationItem.rightBarButtonItems {
            for item in rightItems {
                if let button = item.customView as? UIButton {
                    button.tintColor = color
                    button.setTitleColor(color, for: .normal)
                }
            }
        }
    }
}
