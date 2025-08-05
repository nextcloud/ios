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

    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    var collectionViewCommon: NCCollectionViewCommon? {
        topViewController as? NCCollectionViewCommon
    }

    var trashViewController: NCTrash? {
        topViewController as? NCTrash
    }

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

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: self.global.notificationCenterUpdateNotification), object: nil, queue: nil) { _ in
            Task { @MainActor in
                let capabilities = await NKCapabilities.shared.getCapabilities(for: self.session.account)
                guard capabilities.notification.count > 0 else {
                    if self.isNotificationsButtonVisible() {
                        self.controller?.availableNotifications = false
                        await self.updateRightBarButtonItems()
                    }
                    return
                }

                let resultsNotification = await NextcloudKit.shared.getNotificationsAsync(account: self.session.account)
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
            }
        }

        setNavigationBarHidden(false, animated: true)
    }

    /// Called before a view controller is shown by the navigation controller.
    /// This method checks if the view controller is of type `NCViewerMediaPage`.
    /// If so, it skips applying the custom navigation bar appearance and right bar button items.
    /// Otherwise, it applies the standard appearance and updates buttons accordingly.
    ///
    /// - Parameters:
    ///   - navigationController: The navigation controller that will show the view controller.
    ///   - viewController: The view controller that is about to be shown.
    ///   - animated: True if the transition is animated; false otherwise.

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        Task {
            setNavigationBarAppearance()
            await updateRightBarButtonItems()
        }
    }

    // MARK: - Right

    func setNavigationRightItems() async {
        if let collectionViewCommon,
           collectionViewCommon.isEditMode {
            collectionViewCommon.tabBarSelect?.update(fileSelect: collectionViewCommon.fileSelect, metadatas: collectionViewCommon.getSelectedMetadatas(), userId: session.userId)
            collectionViewCommon.tabBarSelect?.show()

            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                collectionViewCommon.setEditMode(false)
            }
            collectionViewCommon.navigationItem.rightBarButtonItems = [select]
        } else if let trashViewController,
                    trashViewController.isEditMode {
            trashViewController.tabBarSelect.update(selectOcId: [])
            trashViewController.tabBarSelect.show()

            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                trashViewController.setEditMode(false)
            }
            trashViewController.navigationItem.rightBarButtonItems = [select]
        } else {
            trashViewController?.tabBarSelect?.hide()
            collectionViewCommon?.tabBarSelect?.hide()
            await self.updateRightBarButtonItems()
        }
    }

    func updateRightBarButtonItems(_ fileItem: UITabBarItem? = nil) async {
        guard !(collectionViewCommon?.isEditMode ?? false),
              !(trashViewController?.isEditMode ?? false),
              !(topViewController is NCViewerMediaPage),
              !(topViewController is NCViewerPDF),
              !(topViewController is NCViewerRichDocument),
              !(topViewController is NCViewerNextcloudText)
        else {
            return
        }


        let tranfersCount = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "status != %i", self.global.metadataStatusNormal))?.count ?? 0
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        let rightmenu = await createRightMenu()

        await MainActor.run {
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

            if tranfersCount > 0 {
                tempRightBarButtonItems.append(self.transfersButtonItem)
                tempTotalTags += self.transfersButtonItem.tag
            }

            if totalTags != tempTotalTags {
                topViewController?.navigationItem.rightBarButtonItems = tempRightBarButtonItems
            }

            // Update App Icon badge / File Icon badge
#if DEBUG
            UNUserNotificationCenter.current().setBadgeCount(tranfersCount)
            fileItem?.badgeValue = tranfersCount == 0 ? nil : "\(tranfersCount)"
#else
            if tranfersCount > 999 {
                UNUserNotificationCenter.current().setBadgeCount(999)
                fileItem?.badgeValue = "999+"
            } else {
                UNUserNotificationCenter.current().setBadgeCount(tranfersCount)
                fileItem?.badgeValue = tranfersCount == 0 ? nil : "\(tranfersCount)"
            }
#endif
        }
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
                              image: utility.loadImage(named: "checkmark.circle"),
                              attributes: (collectionViewCommon.dataSource.isEmpty() || NCNetworking.shared.isOffline) ? .disabled : []) { _ in
            collectionViewCommon.setEditMode(true)
            collectionViewCommon.collectionView.reloadData()
        }

        let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: utility.loadImage(named: "list.bullet"), state: layoutForView.layout == global.layoutList ? .on : .off) { _ in
            Task {
                layoutForView.layout = self.global.layoutList
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: utility.loadImage(named: "square.grid.2x2"), state: layoutForView.layout == global.layoutGrid ? .on : .off) { _ in
            Task {
                layoutForView.layout = self.global.layoutGrid
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let mediaSquare = UIAction(title: NSLocalizedString("_media_square_", comment: ""), image: utility.loadImage(named: "square.grid.3x3"), state: layoutForView.layout == global.layoutPhotoSquare ? .on : .off) { _ in
            Task {
                layoutForView.layout = self.global.layoutPhotoSquare
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let mediaRatio = UIAction(title: NSLocalizedString("_media_ratio_", comment: ""), image: utility.loadImage(named: "rectangle.grid.3x2"), state: layoutForView.layout == self.global.layoutPhotoRatio ? .on : .off) { _ in
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

        let byName = UIAction(title: NSLocalizedString("_name_", comment: ""), image: isName ? ascendingChevronImage : nil, state: isName ? .on : .off) { _ in
            Task {
                if isName {
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "fileName"
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""), image: isDate ? ascendingChevronImage : nil, state: isDate ? .on : .off) { _ in
            Task {
                if isDate {
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "date"
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""), image: isSize ? ascendingChevronImage : nil, state: isSize ? .on : .off) { _ in
            Task {
                if isSize {
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "size"
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await self.updateRightMenu()
            }
        }

        let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""), options: .displayInline, children: [byName, byNewest, byLargest])

        let favoriteOnTop = NCKeychain().getFavoriteOnTop(account: self.session.account)
        let favoriteOnTopAction = UIAction(title: NSLocalizedString("_favorite_on_top_", comment: ""), state: favoriteOnTop ? .on : .off) { _ in
            Task {
                await NCKeychain().setFavoriteOnTop(account: self.session.account, value: !favoriteOnTop)
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: collectionViewCommon.serverUrl, status: nil)
                }
                await self.updateRightMenu()
            }
        }

        let directoryOnTop = NCKeychain().getDirectoryOnTop(account: self.session.account)
        let directoryOnTopAction = UIAction(title: NSLocalizedString("_directory_on_top_", comment: ""), state: directoryOnTop ? .on : .off) { _ in
            Task {
                await NCKeychain().setDirectoryOnTop(account: self.session.account, value: !directoryOnTop)
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: collectionViewCommon.serverUrl, status: nil)
                }
                await self.updateRightMenu()
            }
        }

        let hiddenFiles = NCKeychain().getShowHiddenFiles(account: self.session.account)
        let hiddenFilesAction = UIAction(title: NSLocalizedString("_show_hidden_files_", comment: ""), state: hiddenFiles ? .on : .off) { _ in
            NCKeychain().setShowHiddenFiles(account: self.session.account, value: !hiddenFiles)
            Task {
                await self.collectionViewCommon?.getServerData(refresh: true)
                await self.updateRightMenu()
            }
        }

        let personalFilesOnly = NCKeychain().getPersonalFilesOnly(account: self.session.account)
        let personalFilesOnlyAction = UIAction(title: NSLocalizedString("_personal_files_only_", comment: ""), image: utility.loadImage(named: "folder.badge.person.crop", colors: NCBrandColor.shared.iconImageMultiColors), state: personalFilesOnly ? .on : .off) { _ in
            NCKeychain().setPersonalFilesOnly(account: self.session.account, value: !personalFilesOnly)

            Task {
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: collectionViewCommon.serverUrl, status: nil)
                }
                await self.updateRightMenu()
            }
        }

        let showDescriptionKeychain = NCKeychain().showDescription
        let showDescription = UIAction(title: NSLocalizedString("_show_description_", comment: ""), state: showDescriptionKeychain ? .on : .off) { _ in
            NCKeychain().showDescription = !showDescriptionKeychain
            Task {
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: collectionViewCommon.serverUrl, status: nil)
                }
                await self.updateRightMenu()
            }
        }

        let showRecommendedFilesKeychain = NCKeychain().showRecommendedFiles
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
        let capabilityRecommendations = capabilities.recommendations

        if capabilityRecommendations {
            showRecommendedFiles = UIAction(title: NSLocalizedString("_show_recommended_files_", comment: ""), state: showRecommendedFilesKeychain ? .on : .off) { _ in
                Task {
                    NCKeychain().showRecommendedFiles = !showRecommendedFilesKeychain
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
        var isSelectAvailable: Bool = false

        if let datasource = trashViewController.datasource, !datasource.isEmpty {
            isSelectAvailable = true
        }

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""), image: utility.loadImage(named: "checkmark.circle", colors: [NCBrandColor.shared.iconImageColor]), attributes: isSelectAvailable ? [] : .disabled) { _ in
            trashViewController.setEditMode(true)
        }
        let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: utility.loadImage(named: "list.bullet", colors: [NCBrandColor.shared.iconImageColor]), state: layoutForView.layout == self.global.layoutList ? .on : .off) { _ in
            Task {
                trashViewController.onListSelected()
                await self.updateRightMenu()
            }
        }
        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: utility.loadImage(named: "square.grid.2x2", colors: [NCBrandColor.shared.iconImageColor]), state: layoutForView.layout == self.global.layoutGrid ? .on : .off) { _ in
            Task {
                trashViewController.onGridSelected()
                await self.updateRightMenu()
            }
        }

        let emptyTrash = UIAction(title: NSLocalizedString("_empty_trash_", comment: ""), image: utility.loadImage(named: "trash", colors: [NCBrandColor.shared.iconImageColor])) { _ in
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

    // MARK: - Left

    func setNavigationLeftItems() async { }
}
