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

    override func viewDidLoad() {
        super.viewDidLoad()

        self.timerProcess = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            var color = NCBrandColor.shared.iconImageColor

            if let results = self.database.getResultsMetadatas(predicate: NSPredicate(format: "status != %i", NCGlobal.shared.metadataStatusNormal)),
               results.count > 0 {
                color = NCBrandColor.shared.customer
            }

            for viewController in self.viewControllers {
                if let rightBarButtonItems = viewController.navigationItem.rightBarButtonItems,
                   let buttonTransfer = rightBarButtonItems.first(where: { $0.tag == self.transfersButtonTag }) {
                    buttonTransfer.tintColor = color
                }
            }
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

    override func setNavigationLeftItems() {
        guard let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", self.session.account))
        else {
            return
        }
        let image = utility.loadUserImage(for: tableAccount.user, displayName: tableAccount.displayName, urlBase: tableAccount.urlBase)
        let accountButton = AccountSwitcherButton(type: .custom)
        let accounts = database.getAllAccountOrderAlias()
        var childrenAccountSubmenu: [UIMenuElement] = []

        accountButton.setImage(image, for: .normal)
        accountButton.setImage(image, for: .highlighted)
        accountButton.semanticContentAttribute = .forceLeftToRight
        accountButton.sizeToFit()

        if !accounts.isEmpty {
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

            accountButton.menu = menu
            accountButton.showsMenuAsPrimaryAction = true

            accountButton.onMenuOpened = {
                self.collectionViewCommon?.dismissTip()
            }
        }

        self.collectionViewCommon?.navigationItem.leftItemsSupplementBackButton = true
        self.collectionViewCommon?.navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: accountButton)], animated: true)
    }

    private class AccountSwitcherButton: UIButton {
        var onMenuOpened: (() -> Void)?

        override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
            super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
            onMenuOpened?()
        }
    }

    override func setNavigationRightItems() {
        guard let collectionViewCommon else {
            return
        }

        func createMenu() -> [UIMenuElement] {
            guard let items = self.createMenuActions()
            else {
                return []
            }

            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [items.foldersOnTop, items.personalFilesOnlyAction, items.showDescription, items.showRecommendedFiles])

            return [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSubmenu]
        }

        if collectionViewCommon.isEditMode {
            collectionViewCommon.tabBarSelect?.update(fileSelect: collectionViewCommon.fileSelect, metadatas: collectionViewCommon.getSelectedMetadatas(), userId: session.userId)
            collectionViewCommon.tabBarSelect?.show()

            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                collectionViewCommon.setEditMode(false)
                collectionViewCommon.collectionView.reloadData()
            }

            self.collectionViewCommon?.navigationItem.rightBarButtonItems = [select]
        } else if self.collectionViewCommon?.navigationItem.rightBarButtonItems == nil || (!collectionViewCommon.isEditMode && !(collectionViewCommon.tabBarSelect?.isHidden() ?? true)) {
            collectionViewCommon.tabBarSelect?.hide()

            let menuButton = UIBarButtonItem(image: utility.loadImage(named: "ellipsis.circle"), menu: UIMenu(children: createMenu()))
            menuButton.tag = menuButtonTag
            menuButton.tintColor = NCBrandColor.shared.iconImageColor

            let transfersButton = UIBarButtonItem(image: utility.loadImage(named: "arrow.left.arrow.right.circle"), style: .plain) {
                if let viewController = UIStoryboard(name: "NCTransfers", bundle: nil).instantiateInitialViewController() as? NCTransfers {
                    viewController.modalPresentationStyle = .pageSheet
                    self.present(viewController, animated: true, completion: nil)
                }
            }

            transfersButton.tag = transfersButtonTag

            let notificationButton = UIBarButtonItem(image: utility.loadImage(named: "bell"), style: .plain) {
                if let viewController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? NCNotification {
                    viewController.session = self.session
                    self.pushViewController(viewController, animated: true)
                }
            }

            notificationButton.tintColor = NCBrandColor.shared.iconImageColor
            notificationButton.tag = notificationButtonTag

            self.collectionViewCommon?.navigationItem.rightBarButtonItems = [menuButton, notificationButton, transfersButton]
        } else {

            self.collectionViewCommon?.navigationItem.rightBarButtonItems?.first?.menu = self.collectionViewCommon?.navigationItem.rightBarButtonItems?.first?.menu?.replacingChildren(createMenu())
        }

        // fix, if the tabbar was hidden before the update, set it in hidden
        if self.tabBarController?.tabBar.isHidden ?? true,
           collectionViewCommon.tabBarSelect?.isHidden() ?? true {
            self.tabBarController?.tabBar.isHidden = true
        }
    }
}
