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

    let menuNavigation = NCContextMenuNavigation()
    var menuPlus: NCContextMenuPlus?

    let menuButtonTag = 100
    let assistantButtonTag = 101
    let notificationsButtonTag = 102
    let transfersButtonTag = 103

    lazy var menuBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem()
        item.tag = menuButtonTag
        return item
    }()
    lazy var assistantButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem()
        item.tag = assistantButtonTag
        return item
    }()
    lazy var notificationsButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem()
        item.tag = notificationsButtonTag
        return item
    }()
    lazy var transfersButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem()
        item.tag = transfersButtonTag
        return item
    }()

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self

        setNavigationBarAppearance()
        setNavigationBarHidden(false, animated: true)

        Task {
            menuBarButtonItem.image = UIImage(systemName: "ellipsis")
            menuBarButtonItem.tintColor = NCBrandColor.shared.iconImageColor
            menuBarButtonItem.menu = await createRightMenu()
        }

        assistantButtonItem.image = UIImage(systemName: "sparkles")
        assistantButtonItem.title = NSLocalizedString("_assistant_", comment: "")
        assistantButtonItem.tintColor = NCBrandColor.shared.iconImageColor
        assistantButtonItem.primaryAction = UIAction(handler: { _ in
            let assistant = NCAssistant(assistantModel: NCAssistantModel(controller: self.controller), chatModel: NCAssistantChatModel(controller: self.controller), conversationsModel: NCAssistantChatConversationsModel(controller: self.controller))
            let hostingController = UIHostingController(rootView: assistant)
            self.present(hostingController, animated: true, completion: nil)
        })

        notificationsButtonItem.image = UIImage(systemName: "bell.fill")
        notificationsButtonItem.title = NSLocalizedString("_notifications_", comment: "")
        notificationsButtonItem.tintColor = NCBrandColor.shared.iconImageColor
        notificationsButtonItem.primaryAction = UIAction(handler: { _ in
            if let navigationController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? UINavigationController,
               let viewController = navigationController.topViewController as? NCNotification {
                viewController.modalPresentationStyle = .pageSheet
                viewController.session = self.session
                self.present(navigationController, animated: true, completion: nil)
            }
        })

        transfersButtonItem.image = UIImage(systemName: "arrow.left.arrow.right.circle.fill")
        transfersButtonItem.title = NSLocalizedString("_transfers_", comment: "")
        transfersButtonItem.tintColor = NCBrandColor.shared.iconImageColor
        transfersButtonItem.primaryAction = UIAction(handler: { _ in
            let rootView = TransfersView(session: self.session, onClose: { [weak self] in
                self?.dismiss(animated: true)
            })
            let hosting = UIHostingController(rootView: rootView)
            hosting.modalPresentationStyle = .pageSheet

            self.present(hosting, animated: true)
        })

        // PLUS BUTTON MENU
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

        menuPlus = NCContextMenuPlus(menuToolbar: menuToolbar, controller: controller)

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: self.global.notificationCenterServerDidUpdate), object: nil, queue: nil) { notification in
            guard let userInfo = notification.userInfo,
                  let account = userInfo["account"] as? String else {
                return
            }

            Task { @MainActor in
                let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
                let session = NCSession.shared.getSession(account: account)

                // Notification
                //
                if capabilities.notification.count == 0 {
                    self.controller?.availableNotifications = false
                } else {
                    _ = await NextcloudKit.shared.getNotificationsAsync(account: account) { task in
                        Task {
                            let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                                account: account,
                                name: "getNotifications"
                            )
                            await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                        }
                    }
                    self.controller?.availableNotifications = true
                }
                await self.updateRightBarButtonItems()
                await self.menuPlus?.create(session: session)
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: self.global.notificationCenterNetworkReachability), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Menu Plus
                await self.menuPlus?.create(session: session)
            }
        }
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        Task { @MainActor in
            // PLUS BUTTON
            if viewController is NCFiles {
                self.menuPlus?.hiddenPlusButton(false)
            } else {
                self.menuPlus?.hiddenPlusButton(true, animation: false)
            }
            // MENU
            setNavigationBarAppearance()
            await updateRightBarButtonItems()
        }
    }

    // MARK: - Right

    @MainActor
    func setNavigationRightItems() async {

        // COLLECTION EDIT MODE
        if let collectionViewCommon, collectionViewCommon.isEditMode {

            collectionViewCommon.tabBarSelect?.update(
                fileSelect: collectionViewCommon.fileSelect,
                metadatas: collectionViewCommon.getSelectedMetadatas(),
                userId: session.userId
            )
            collectionViewCommon.tabBarSelect?.show()
            collectionViewCommon.navigationItem.searchController = nil

            let cancel = UIBarButtonItem(
                title: NSLocalizedString("_cancel_", comment: ""),
                style: .plain
            ) {
                Task {
                    await collectionViewCommon.setEditMode(false)
                }
            }

            let group = UIBarButtonItemGroup(
                barButtonItems: [cancel],
                representativeItem: nil
            )

            collectionViewCommon.navigationItem.trailingItemGroups = [group]
            return
        }

        // TRASH EDIT MODE
        if let trashViewController, trashViewController.isEditMode {

            trashViewController.tabBarSelect.update(selectOcId: [])
            trashViewController.tabBarSelect.show()

            let cancel = UIBarButtonItem(
                title: NSLocalizedString("_cancel_", comment: ""),
                style: .plain
            ) {
                trashViewController.setEditMode(false)
            }

            let group = UIBarButtonItemGroup(
                barButtonItems: [cancel],
                representativeItem: nil
            )

            trashViewController.navigationItem.trailingItemGroups = [group]
            return
        }

        // NORMAL MODE
        trashViewController?.tabBarSelect?.hide()
        collectionViewCommon?.tabBarSelect?.hide()
        collectionViewCommon?.navigationItem.searchController = collectionViewCommon?.searchController
        await updateRightBarButtonItems()
    }

    @MainActor
    func updateRightBarButtonItems(_ fileItem: UITabBarItem? = nil) async {
        guard let topViewController else {
            return
        }

        guard !(collectionViewCommon?.isEditMode ?? false),
              !(trashViewController?.isEditMode ?? false),
              !(mediaViewController?.isEditMode ?? false),
              !(topViewController is NCViewerMediaPage),
              !(topViewController is NCViewerPDF),
              !(topViewController is NCViewerRichDocument),
              !(topViewController is NCViewerNextcloudText)
        else {
            return
        }

        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        let rightMenu = await createRightMenu()

        // ---------------------------------------------------------
        // Build desired items
        // ---------------------------------------------------------

        var desiredItems: [UIBarButtonItem] = []

        if controller?.availableNotifications ?? false {
            desiredItems.append(notificationsButtonItem)
        }

        if capabilities.assistantEnabled {
            desiredItems.append(assistantButtonItem)
        }

        desiredItems.append(transfersButtonItem)

        if let rightMenu {
            menuBarButtonItem.menu = rightMenu
            desiredItems.append(menuBarButtonItem)
        }

        // ---------------------------------------------------------
        // Read current items from trailingItemGroups
        // ---------------------------------------------------------

        let currentItems: [UIBarButtonItem] = topViewController.navigationItem.trailingItemGroups.flatMap { $0.barButtonItems }

        let currentTags = currentItems.map { $0.tag }
        let desiredTags = desiredItems.map { $0.tag }

        // If nothing changed → exit
        guard currentTags != desiredTags else {
            return
        }

        // ---------------------------------------------------------
        // Apply new group
        // ---------------------------------------------------------

        let group = UIBarButtonItemGroup(
            barButtonItems: desiredItems,
            representativeItem: nil
        )

        topViewController.navigationItem.trailingItemGroups = [group]
    }

    func createRightMenu() async -> UIMenu? { return nil }

    func updateRightMenu() async {
        if topViewController?.navigationItem.rightBarButtonItems?.first(where: { $0.tag == menuButtonTag }) != nil {
            menuBarButtonItem.menu = await createRightMenu()
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
            let item = items.first(where: { $0.tag == tag })
        else { return }

        applyTint(item, color: color)
    }

    /// Changes the tint color of all left bar button items currently visible
    /// in the topViewController's navigation item.
    /// - Parameter color: The UIColor to be applied.
    @MainActor
    func setAllLeftItemsColor(_ color: UIColor) {
        guard let items = topViewController?.navigationItem.leftBarButtonItems else { return }

        for item in items {
            applyTint(item, color: color)
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

    @MainActor
    private func applyTint(_ item: UIBarButtonItem, color: UIColor) {
        if let button = item.customView as? UIButton {
            applyTint(button, color: color)
        } else {
            item.tintColor = color
        }
    }

    /// Updates the tint color of all preloaded and currently visible right bar buttons.
    /// - Parameter color: The UIColor to be applied to all right bar button items.
    @MainActor
    func updateRightBarButtonsTint(to color: UIColor) {
        let rightItems: [UIBarButtonItem] = [
            menuBarButtonItem,
            assistantButtonItem,
            notificationsButtonItem,
            transfersButtonItem
        ]

        for item in rightItems {
            applyTint(item, color: color)
        }

        if let visibleItems = topViewController?.navigationItem.rightBarButtonItems {
            for item in visibleItems {
                applyTint(item, color: color)
            }
        }
    }
}
