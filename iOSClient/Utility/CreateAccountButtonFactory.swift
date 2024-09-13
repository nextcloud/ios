//
//  CreateAccountButtonFactory.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 12.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit
import SwiftUI
import RealmSwift
import NextcloudKit
import EasyTipView

class CreateAccountButtonFactory {
    let utility = NCUtility()
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    
    private var onAccountDetailsOpen: (() -> Void)
    private var presentVC: ((UIViewController) -> Void)
    private var onMenuOpened: (() -> Void)?
    
    init(onAccountDetailsOpen: (@escaping () -> Void),
         presentVC: (@escaping (UIViewController) -> Void),
         onMenuOpened: (() -> Void)? = nil) {
        self.onAccountDetailsOpen = onAccountDetailsOpen
        self.presentVC = presentVC
        self.onMenuOpened = onMenuOpened
    }
    
    func createAccountButton() -> UIBarButtonItem {
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        let image = utility.loadUserImage(for: appDelegate.user, displayName: activeAccount?.displayName, userBaseUrl: appDelegate)
        let accountButton = AccountSwitcherButton(type: .custom)
        let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()
        var childrenAccountSubmenu: [UIMenuElement] = []
        
        accountButton.setImage(image, for: .normal)
        accountButton.setImage(image, for: .highlighted)
        accountButton.semanticContentAttribute = .forceLeftToRight
        accountButton.sizeToFit()
        
        if !accounts.isEmpty {
            let accountActions: [UIAction] = accounts.map { account in
                let image = utility.loadUserImage(for: account.user, displayName: account.displayName, userBaseUrl: account)
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
                        self.appDelegate.changeAccount(account.account, userProfile: nil) { }
                        self.onAccountDetailsOpen()
                    }
                }
                
                action.subtitle = url
                return action
            }
            
            let addAccountAction = UIAction(title: NSLocalizedString("_add_account_", comment: ""), image: utility.loadImage(named: "person.crop.circle.badge.plus", colors: NCBrandColor.shared.iconImageMultiColors)) { _ in
                self.appDelegate.openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }
            
            let settingsAccountAction = UIAction(title: NSLocalizedString("_account_settings_", comment: ""), image: utility.loadImage(named: "gear", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                let accountSettingsModel = NCAccountSettingsModel(delegate: self)
                let accountSettingsView = NCAccountSettingsView(model: accountSettingsModel)
                let accountSettingsController = UIHostingController(rootView: accountSettingsView)
                self.presentVC(accountSettingsController)
            }
            
            if !NCBrandOptions.shared.disable_multiaccount {
                childrenAccountSubmenu.append(addAccountAction)
            }
            childrenAccountSubmenu.append(settingsAccountAction)
            
            let addAccountSubmenu = UIMenu(title: "", options: .displayInline, children: childrenAccountSubmenu)
            let menu = UIMenu(children: accountActions + [addAccountSubmenu])
            
            accountButton.menu = menu
            accountButton.showsMenuAsPrimaryAction = true
            
            accountButton.onMenuOpened = onMenuOpened
        }
        return UIBarButtonItem(customView: accountButton)
    }
}

extension CreateAccountButtonFactory: NCAccountSettingsModelDelegate {
    func accountSettingsDidDismiss(tableAccount: tableAccount?) {
        if NCManageDatabase.shared.getAllAccount().isEmpty {
            appDelegate.openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: false)
        } else if let account = tableAccount?.account, account != appDelegate.account {
            appDelegate.changeAccount(account, userProfile: nil) { }
        }
    }
}

// MARK: -

private class AccountSwitcherButton: UIButton {
    var onMenuOpened: (() -> Void)?

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
        onMenuOpened?()
    }
}
