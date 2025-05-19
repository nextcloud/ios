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

    let menuButton = UIButton(type: .system)
    var menuBarButtonItem: UIBarButtonItem {
        let item = UIBarButtonItem(customView: menuButton)
        item.tag = menuButtonTag
        return item
    }

    let assistantButton = UIButton(type: .system)
    var assistantButtonItem: UIBarButtonItem {
        let item = UIBarButtonItem(customView: assistantButton)
        item.tag = assistantButtonTag
        return item
    }

    let notificationsButton = UIButton(type: .system)
    var notificationsButtonItem: UIBarButtonItem {
        let item = UIBarButtonItem(customView: notificationsButton)
        item.tag = notificationsButtonTag
        return item
    }

    let transfersButton = UIButton(type: .system)
    var transfersButtonItem: UIBarButtonItem {
        let item = UIBarButtonItem(customView: transfersButton)
        item.tag = transfersButtonTag
        return item
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self

        menuButton.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        menuButton.tintColor = NCBrandColor.shared.iconImageColor
        menuButton.menu = createRightMenu()
        menuButton.showsMenuAsPrimaryAction = true

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

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUpdateNotification), object: nil, queue: nil) { _ in
            let capabilities = NCCapabilities.shared.getCapabilities(account: self.session.account)
            if capabilities.capabilityNotification.count > 0 {
                NextcloudKit.shared.getNotifications(account: self.session.account) { _ in
                } completion: { _, notifications, _, error in
                    if error == .success,
                       let notifications,
                       notifications.count > 0 {
                        if !self.isNotificationsButtonVisible() {
                            self.controller?.availableNotifications = true
                            self.updateRightBarButtonItems()
                        }
                    } else {
                        if self.isNotificationsButtonVisible() {
                            self.controller?.availableNotifications = false
                            self.updateRightBarButtonItems()
                        }
                    }
                }
            } else {
                if self.isNotificationsButtonVisible() {
                    self.controller?.availableNotifications = false
                    self.updateRightBarButtonItems()
                }
            }
        }

        navigationBar.prefersLargeTitles = true
        setNavigationBarHidden(false, animated: true)
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        setNavigationBarAppearance()
        self.updateRightBarButtonItems()
    }

    // MARK: - Right

    func setNavigationRightItems() {
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
            self.updateRightBarButtonItems()
        }
    }

    func updateRightBarButtonItems(_ fileItem: UITabBarItem? = nil) {
        guard !(collectionViewCommon?.isEditMode ?? false),
              !(trashViewController?.isEditMode ?? false),
              !(topViewController is NCViewerMediaPage),
              !(topViewController is NCViewerPDF),
              !(topViewController is NCViewerRichDocument),
              !(topViewController is NCViewerNextcloudText)
        else {
            return
        }

        let capabilities = NCCapabilities.shared.getCapabilities(account: session.account)
        let resultsCount = self.database.getResultsMetadatas(predicate: NSPredicate(format: "status != %i", NCGlobal.shared.metadataStatusNormal))?.count ?? 0
        var tempRightBarButtonItems: [UIBarButtonItem] = createRightMenu() == nil ? [] : [self.menuBarButtonItem]
        var tempTotalTags = tempRightBarButtonItems.count == 0 ? 0 : self.menuBarButtonItem.tag
        var totalTags = 0

        if let rightBarButtonItems = topViewController?.navigationItem.rightBarButtonItems {
            for item in rightBarButtonItems {
                totalTags = totalTags + item.tag
            }
        }

        if capabilities.capabilityAssistantEnabled {
            tempRightBarButtonItems.append(self.assistantButtonItem)
            tempTotalTags = tempTotalTags + self.assistantButtonItem.tag
        }

        if let controller, controller.availableNotifications {
            tempRightBarButtonItems.append(self.notificationsButtonItem)
            tempTotalTags = tempTotalTags + self.notificationsButtonItem.tag
        }

        if resultsCount > 0 {
            tempRightBarButtonItems.append(self.transfersButtonItem)
            tempTotalTags = tempTotalTags + self.transfersButtonItem.tag
        }

        if totalTags != tempTotalTags {
            topViewController?.navigationItem.rightBarButtonItems = tempRightBarButtonItems
        }

        // Update App Icon badge / File Icon badge
#if DEBUG
        if UIApplication.shared.applicationIconBadgeNumber != resultsCount {
            UIApplication.shared.applicationIconBadgeNumber = resultsCount
        }
        fileItem?.badgeValue = resultsCount == 0 ? nil : "\(resultsCount)"
#else
        if resultsCount > 999 {
            UIApplication.shared.applicationIconBadgeNumber = 999
            fileItem?.badgeValue = "999+"
        } else {
            if UIApplication.shared.applicationIconBadgeNumber != resultsCount {
                UIApplication.shared.applicationIconBadgeNumber = resultsCount
            }
            fileItem?.badgeValue = resultsCount == 0 ? nil : "\(resultsCount)"
        }
#endif
    }

    func createRightMenu() -> UIMenu? { return nil }

    func updateRightMenu() {
        if let rightBarButtonItems = topViewController?.navigationItem.rightBarButtonItems,
            let menuBarButtonItem = rightBarButtonItems.first(where: { $0.tag == menuButtonTag }),
            let menuButton = menuBarButtonItem.customView as? UIButton {
            menuButton.menu = createRightMenu()
        }
    }

    func createRightMenuActions() -> (select: UIAction,
                                      viewStyleSubmenu: UIMenu,
                                      sortSubmenu: UIMenu,
                                      favoriteOnTop: UIAction,
                                      directoryOnTop: UIAction,
                                      hiddenFiles: UIAction,
                                      personalFilesOnly: UIAction,
                                      showDescription: UIAction,
                                      showRecommendedFiles: UIAction?)? {
        var showRecommendedFiles: UIAction?

        guard let collectionViewCommon,
              let layoutForView = database.getLayoutForView(account: session.account, key: collectionViewCommon.layoutKey, serverUrl: collectionViewCommon.serverUrl)
        else {
            return nil
        }

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                              image: utility.loadImage(named: "checkmark.circle"),
                              attributes: (collectionViewCommon.dataSource.isEmpty() || NCNetworking.shared.isOffline) ? .disabled : []) { _ in
            collectionViewCommon.setEditMode(true)
            collectionViewCommon.collectionView.reloadData()
        }

        let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: utility.loadImage(named: "list.bullet"), state: layoutForView.layout == global.layoutList ? .on : .off) { _ in
            layoutForView.layout = self.global.layoutList
            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: utility.loadImage(named: "square.grid.2x2"), state: layoutForView.layout == global.layoutGrid ? .on : .off) { _ in
            layoutForView.layout = self.global.layoutGrid
            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let mediaSquare = UIAction(title: NSLocalizedString("_media_square_", comment: ""), image: utility.loadImage(named: "square.grid.3x3"), state: layoutForView.layout == global.layoutPhotoSquare ? .on : .off) { _ in
            layoutForView.layout = self.global.layoutPhotoSquare
            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let mediaRatio = UIAction(title: NSLocalizedString("_media_ratio_", comment: ""), image: utility.loadImage(named: "rectangle.grid.3x2"), state: layoutForView.layout == self.global.layoutPhotoRatio ? .on : .off) { _ in
            layoutForView.layout = self.global.layoutPhotoRatio
            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid, mediaSquare, mediaRatio])

        let ascending = layoutForView.ascending
        let ascendingChevronImage = utility.loadImage(named: ascending ? "chevron.up" : "chevron.down")
        let isName = layoutForView.sort == "fileName"
        let isDate = layoutForView.sort == "date"
        let isSize = layoutForView.sort == "size"

        let byName = UIAction(title: NSLocalizedString("_name_", comment: ""), image: isName ? ascendingChevronImage : nil, state: isName ? .on : .off) { _ in
            if isName {
                layoutForView.ascending = !layoutForView.ascending
            }
            layoutForView.sort = "fileName"
            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""), image: isDate ? ascendingChevronImage : nil, state: isDate ? .on : .off) { _ in
            if isDate {
                layoutForView.ascending = !layoutForView.ascending
            }
            layoutForView.sort = "date"
            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""), image: isSize ? ascendingChevronImage : nil, state: isSize ? .on : .off) { _ in
            if isSize {
                layoutForView.ascending = !layoutForView.ascending
            }
            layoutForView.sort = "size"
            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""), options: .displayInline, children: [byName, byNewest, byLargest])

        let favoriteOnTop = NCKeychain().getFavoriteOnTop(account: self.session.account)
        let favoriteOnTopAction = UIAction(title: NSLocalizedString("_favorite_on_top_", comment: ""), state: favoriteOnTop ? .on : .off) { _ in
            NCKeychain().setFavoriteOnTop(account: self.session.account, value: !favoriteOnTop)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": collectionViewCommon.serverUrl, "clearDataSource": true])
            self.updateRightMenu()
        }

        let directoryOnTop = NCKeychain().getDirectoryOnTop(account: self.session.account)
        let directoryOnTopAction = UIAction(title: NSLocalizedString("_directory_on_top_", comment: ""), state: directoryOnTop ? .on : .off) { _ in
            NCKeychain().setDirectoryOnTop(account: self.session.account, value: !directoryOnTop)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": collectionViewCommon.serverUrl, "clearDataSource": true])
            self.updateRightMenu()
        }

        let hiddenFiles = NCKeychain().getShowHiddenFiles(account: self.session.account)
        let hiddenFilesAction = UIAction(title: NSLocalizedString("_show_hidden_files_", comment: ""), state: hiddenFiles ? .on : .off) { _ in
            NCKeychain().setShowHiddenFiles(account: self.session.account, value: !hiddenFiles)
            self.collectionViewCommon?.dataSource.removeAll()
            self.collectionViewCommon?.getServerData()
            self.updateRightMenu()
        }

        let personalFilesOnly = NCKeychain().getPersonalFilesOnly(account: self.session.account)
        let personalFilesOnlyAction = UIAction(title: NSLocalizedString("_personal_files_only_", comment: ""), image: utility.loadImage(named: "folder.badge.person.crop", colors: NCBrandColor.shared.iconImageMultiColors), state: personalFilesOnly ? .on : .off) { _ in
            NCKeychain().setPersonalFilesOnly(account: self.session.account, value: !personalFilesOnly)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": collectionViewCommon.serverUrl, "clearDataSource": true])
            self.updateRightMenu()
        }

        let showDescriptionKeychain = NCKeychain().showDescription
        let showDescription = UIAction(title: NSLocalizedString("_show_description_", comment: ""), state: showDescriptionKeychain ? .on : .off) { _ in
            NCKeychain().showDescription = !showDescriptionKeychain
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": collectionViewCommon.serverUrl, "clearDataSource": true])
            self.updateRightMenu()
        }

        let showRecommendedFilesKeychain = NCKeychain().showRecommendedFiles
        let capabilityRecommendations = NCCapabilities.shared.getCapabilities(account: session.account).capabilityRecommendations
        if capabilityRecommendations {
            showRecommendedFiles = UIAction(title: NSLocalizedString("_show_recommended_files_", comment: ""), state: showRecommendedFilesKeychain ? .on : .off) { _ in
                NCKeychain().showRecommendedFiles = !showRecommendedFilesKeychain
                collectionViewCommon.collectionView.reloadData()
                self.updateRightMenu()
            }
        }

        return (select, viewStyleSubmenu, sortSubmenu, favoriteOnTopAction, directoryOnTopAction, hiddenFilesAction, personalFilesOnlyAction, showDescription, showRecommendedFiles)
    }

    func createTrashRightMenuActions() -> [UIMenuElement]? {
        guard let trashViewController,
              let layoutForView = self.database.getLayoutForView(account: session.account, key: trashViewController.layoutKey, serverUrl: "")
        else {
            return nil
        }
        var isSelectAvailable: Bool = false

        if let datasource = trashViewController.datasource, !datasource.isEmpty {
            isSelectAvailable = true
        }

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""), image: utility.loadImage(named: "checkmark.circle", colors: [NCBrandColor.shared.iconImageColor]), attributes: isSelectAvailable ? [] : .disabled) { _ in
            trashViewController.setEditMode(true)
        }
        let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: utility.loadImage(named: "list.bullet", colors: [NCBrandColor.shared.iconImageColor]), state: layoutForView.layout == NCGlobal.shared.layoutList ? .on : .off) { _ in
            trashViewController.onListSelected()
            self.updateRightMenu()
        }
        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: utility.loadImage(named: "square.grid.2x2", colors: [NCBrandColor.shared.iconImageColor]), state: layoutForView.layout == NCGlobal.shared.layoutGrid ? .on : .off) { _ in
            trashViewController.onGridSelected()
            self.updateRightMenu()
        }
        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid])

        return [select, viewStyleSubmenu]
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

    func setNavigationLeftItems() { }
}
