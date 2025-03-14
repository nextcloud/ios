// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

class NCFilesNavigationController: NCMainNavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()

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

    // MARK: - Right

    override func createRightMenu() -> UIMenu? {
        guard let items = self.createRightMenuActions(),
              let collectionViewCommon
        else {
            return nil
        }

        if collectionViewCommon.serverUrl == utilityFileSystem.getHomeServer(session: session) {
            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [items.foldersOnTop, items.personalFilesOnlyAction, items.showDescription, items.showRecommendedFiles])
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSubmenu])

        } else {
            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [items.foldersOnTop, items.showDescription])
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSubmenu])
        }
    }

    // MARK: - Left

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

            accountButton.accessibilityIdentifier = "accountSwitcher"
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
}
