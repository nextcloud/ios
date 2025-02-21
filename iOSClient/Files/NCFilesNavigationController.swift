// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

class NCFilesNavigationController: NCMainNavigationController {
    private var timerProcess: Timer?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    let menuButton = UIButton(type: .system)
    var menuBarButtonItem: UIBarButtonItem {
        let item = UIBarButtonItem(customView: menuButton)
        item.tag = menuButtonTag
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

    override func viewDidLoad() {
        super.viewDidLoad()

        menuButton.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        menuButton.tintColor = NCBrandColor.shared.iconImageColor
        menuButton.menu = createRightMenu()
        menuButton.showsMenuAsPrimaryAction = true

        notificationsButton.setImage(UIImage(systemName: "bell.fill"), for: .normal)
        notificationsButton.tintColor = NCBrandColor.shared.iconImageColor
        notificationsButton.addAction(UIAction(handler: { _ in
            if let viewController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? NCNotification {
                viewController.session = self.session
                self.pushViewController(viewController, animated: true)
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

        self.timerProcess = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.updateRightBarButtonItems()
        })

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil, queue: nil) { notification in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.collectionViewCommon?.showTip()
            }
            guard let userInfo = notification.userInfo as NSDictionary?,
                  let error = userInfo["error"] as? NKError,
                  error.errorCode != self.global.errorNotModified
            else {
                return
            }

            self.setNavigationLeftItems()
        }
    }

    override func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        super.navigationController(navigationController, willShow: viewController, animated: animated)
        self.updateRightBarButtonItems()
    }

    // MARK: -

    func updateRightBarButtonItems() {
        guard let collectionViewCommon,
              !collectionViewCommon.isEditMode
        else {
            return
        }
        let resultsCount = self.database.getResultsMetadatas(predicate: NSPredicate(format: "status != %i", NCGlobal.shared.metadataStatusNormal))?.count ?? 0
        var tempRightBarButtonItems = [self.menuBarButtonItem]

        if controller?.availableNotifications ?? false {
            tempRightBarButtonItems.append(self.notificationsButtonItem)
        }

        if resultsCount > 0 {
            tempRightBarButtonItems.append(self.transfersButtonItem)
        }

        if collectionViewCommon.navigationItem.rightBarButtonItems?.count != tempRightBarButtonItems.count {
            collectionViewCommon.navigationItem.rightBarButtonItems = tempRightBarButtonItems
        }
    }

    func createRightMenu() -> UIMenu? {
        guard let items = self.createMenuActions(),
              let collectionViewCommon
        else {
            return nil
        }

        if collectionViewCommon.serverUrl == utilityFileSystem.getHomeServer(session: session) {
            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [items.foldersOnTop, items.personalFilesOnlyAction, items.showDescription, items.showRecommendedFiles])
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSubmenu])

        } else {
            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [items.foldersOnTop, items.personalFilesOnlyAction, items.showDescription])
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSubmenu])
        }
    }

    override func setNavigationLeftItems() {
        guard let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", self.session.account))
        else {
            self.collectionViewCommon?.navigationItem.leftBarButtonItems = nil
            return
        }
        let image = utility.loadUserImage(for: tableAccount.user, displayName: tableAccount.displayName, urlBase: tableAccount.urlBase)

        class AccountSwitcherButton: UIButton {
            var onMenuOpened: (() -> Void)?

            override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
                super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
                onMenuOpened?()
            }
        }

        func createLeftMenu() -> UIMenu? {
            var childrenAccountSubmenu: [UIMenuElement] = []
            let accounts = database.getAllAccountOrderAlias()
            guard !accounts.isEmpty
            else {
                return nil
            }

            let accountActions: [UIAction] = accounts.map { account in
                let image = utility.loadUserImage(for: account.user, displayName: account.displayName, urlBase: account.urlBase)
                var name: String = ""
                var url: String = ""

                if account.alias.isEmpty {
                    name = account.displayName
                    url = (URL(string: account.urlBase)?.host ?? "")
                } else {
                    name = account.alias
                }

                let action = UIAction(title: name, image: image, state: account.active ? .on : .off) { _ in
                    if !account.active {
                        NCAccount().changeAccount(account.account, userProfile: nil, controller: self.controller) { }
                        self.collectionViewCommon?.setEditMode(false)
                    }
                }

                action.subtitle = url
                return action
            }

            let addAccountAction = UIAction(title: NSLocalizedString("_add_account_", comment: ""), image: utility.loadImage(named: "person.crop.circle.badge.plus", colors: NCBrandColor.shared.iconImageMultiColors)) { _ in
                self.appDelegate.openLogin(selector: self.global.introLogin)
            }

            let settingsAccountAction = UIAction(title: NSLocalizedString("_account_settings_", comment: ""), image: utility.loadImage(named: "gear", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                let accountSettingsModel = NCAccountSettingsModel(controller: self.controller, delegate: self.collectionViewCommon)
                let accountSettingsView = NCAccountSettingsView(model: accountSettingsModel)
                let accountSettingsController = UIHostingController(rootView: accountSettingsView)

                self.present(accountSettingsController, animated: true, completion: nil)
            }

            if !NCBrandOptions.shared.disable_multiaccount {
                childrenAccountSubmenu.append(addAccountAction)
            }
            childrenAccountSubmenu.append(settingsAccountAction)

            let addAccountSubmenu = UIMenu(title: "", options: .displayInline, children: childrenAccountSubmenu)
            let menu = UIMenu(children: accountActions + [addAccountSubmenu])

            return menu
        }

        if self.collectionViewCommon?.navigationItem.leftBarButtonItems == nil {
            let accountButton = AccountSwitcherButton(type: .custom)

            accountButton.setImage(image, for: .normal)
            accountButton.semanticContentAttribute = .forceLeftToRight
            accountButton.sizeToFit()

            accountButton.menu = createLeftMenu()
            accountButton.showsMenuAsPrimaryAction = true

            accountButton.onMenuOpened = {
                self.collectionViewCommon?.dismissTip()
            }

            self.collectionViewCommon?.navigationItem.leftItemsSupplementBackButton = true
            self.collectionViewCommon?.navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: accountButton)], animated: true)

        } else {

            let accountButton = self.collectionViewCommon?.navigationItem.leftBarButtonItems?.first?.customView as? UIButton
            accountButton?.setImage(image, for: .normal)
            accountButton?.menu = createLeftMenu()
        }
    }

    override func setNavigationRightItems() {
        guard let collectionViewCommon else {
            self.collectionViewCommon?.navigationItem.rightBarButtonItems = nil
            return
        }

        if collectionViewCommon.isEditMode {
            collectionViewCommon.tabBarSelect?.update(fileSelect: collectionViewCommon.fileSelect, metadatas: collectionViewCommon.getSelectedMetadatas(), userId: session.userId)
            collectionViewCommon.tabBarSelect?.show()

            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                collectionViewCommon.setEditMode(false)
                collectionViewCommon.collectionView.reloadData()
                collectionViewCommon.navigationItem.rightBarButtonItems = [self.menuBarButtonItem]
            }

            self.collectionViewCommon?.navigationItem.rightBarButtonItems = [select]

        } else if self.collectionViewCommon?.navigationItem.rightBarButtonItems == nil || (!collectionViewCommon.isEditMode && !(collectionViewCommon.tabBarSelect?.isHidden() ?? true)) {
            collectionViewCommon.tabBarSelect?.hide()

            self.updateRightBarButtonItems()

        } else {

            if let rightBarButtonItems = self.collectionViewCommon?.navigationItem.rightBarButtonItems,
               let menuBarButtonItem = rightBarButtonItems.first(where: { $0.tag == menuButtonTag }),
               let menuButton = menuBarButtonItem.customView as? UIButton {
                menuButton.menu = createRightMenu()
            }
        }

        // fix, if the tabbar was hidden before the update, set it in hidden
        if self.tabBarController?.tabBar.isHidden ?? true,
           collectionViewCommon.tabBarSelect?.isHidden() ?? true {
            self.tabBarController?.tabBar.isHidden = true
        }
    }
}
