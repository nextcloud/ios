//
//  AccountButtonFactory.swift
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

class AccountButtonFactory {
    let database = NCManageDatabase.shared
    let utility = NCUtility()
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    var controller: NCMainTabBarController?
    
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
        let session = NCSession.shared.getSession(controller: controller)
        guard let tableAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) else {
            return UIBarButtonItem()
        }
        let image = utility.loadUserImage(for: tableAccount.account, displayName: tableAccount.displayName, urlBase: tableAccount.urlBase)
        let accountButton = AccountSwitcherButton(type: .custom)
        let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()
        
        accountButton.setImage(image, for: .normal)
        accountButton.setImage(image, for: .highlighted)
        accountButton.semanticContentAttribute = .forceLeftToRight
        accountButton.sizeToFit()
        accountButton.action(for: .touchUpInside, { [weak self] _ in
            let accountSettingsModel = NCAccountSettingsModel(controller: self?.controller, delegate: self)
            let accountSettingsView = NCAccountSettingsView(model: accountSettingsModel)
            let accountSettingsController = UIHostingController(rootView: accountSettingsView)
            self?.presentVC(accountSettingsController)
        })
        return UIBarButtonItem(customView: accountButton)
    }
}

extension AccountButtonFactory: NCAccountSettingsModelDelegate {
    func accountSettingsDidDismiss(tableAccount: tableAccount?, controller: NCMainTabBarController?) {
        let session = NCSession.shared.getSession(controller: controller)
        let currentAccount = session.account
        if database.getAllTableAccount().isEmpty {
            appDelegate.openLogin(selector: NCGlobal.shared.introLogin)
        } else if let account = tableAccount?.account, account != currentAccount {
            NCAccount().changeAccount(account, userProfile: nil, controller: controller) { }
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
