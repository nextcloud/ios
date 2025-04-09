//
//  AccountButtonFactory.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 12.09.2024.
//  Copyright © 2024 STRATO GmbH
//

import UIKit
import SwiftUI
import RealmSwift
import NextcloudKit
import EasyTipView

class AccountButtonFactory {
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
        let image = utility.userImage
        let accountButton = AccountSwitcherButton(type: .custom)
        let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()
        
        accountButton.setImage(image, for: .normal)
        accountButton.setImage(image, for: .highlighted)
        accountButton.semanticContentAttribute = .forceLeftToRight
        accountButton.sizeToFit()
        accountButton.action(for: .touchUpInside, { _ in
            let accountSettingsModel = NCAccountSettingsModel(delegate: self)
            let accountSettingsView = NCAccountSettingsView(model: accountSettingsModel)
            let accountSettingsController = UIHostingController(rootView: accountSettingsView)
            self.presentVC(accountSettingsController)
        })
        return UIBarButtonItem(customView: accountButton)
    }
}

extension AccountButtonFactory: NCAccountSettingsModelDelegate {
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
