import UIKit
import SwiftUI
import RealmSwift
import NextcloudKit

class NCFilesNavigationController: UINavigationController {
    private var timerProcess: Timer?
    private let database = NCManageDatabase.shared
    private let global = NCGlobal.shared
    private let utility = NCUtility()
    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    private var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setNavigationBarAppearance()
        navigationBar.prefersLargeTitles = true
        setNavigationBarHidden(false, animated: true)

        self.timerProcess = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            var color = NCBrandColor.shared.iconImageColor

            if let results = self.database.getResultsMetadatas(predicate: NSPredicate(format: "status != %i", NCGlobal.shared.metadataStatusNormal)),
               results.count > 0 {
                color = NCBrandColor.shared.customer
            }

            if let viewController = self.viewControllers.first,
               let rightBarButtonItems = viewController.navigationItem.rightBarButtonItems,
               let buttonTransfer = rightBarButtonItems.first(where: { $0.tag == 2 }) {
                buttonTransfer.tintColor = color

            }
        })
    }

    func setNavigationLeftItems() {
        let session = NCSession.shared.getSession(controller: tabBarController)
        guard let viewController = topViewController as? NCFiles,
              let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) else {
            return }
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
                        viewController.setEditMode(false)
                    }
                }

                action.subtitle = url
                return action
            }

            let addAccountAction = UIAction(title: NSLocalizedString("_add_account_", comment: ""), image: utility.loadImage(named: "person.crop.circle.badge.plus", colors: NCBrandColor.shared.iconImageMultiColors)) { _ in
                self.appDelegate.openLogin(selector: self.global.introLogin)
            }

            let settingsAccountAction = UIAction(title: NSLocalizedString("_account_settings_", comment: ""), image: utility.loadImage(named: "gear", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                let accountSettingsModel = NCAccountSettingsModel(controller: self.controller, delegate: viewController)
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
                viewController.dismissTip()
            }
        }

        viewController.navigationItem.leftItemsSupplementBackButton = true
        viewController.navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: accountButton)], animated: true)
    }

    private class AccountSwitcherButton: UIButton {
        var onMenuOpened: (() -> Void)?

        override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
            super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
            onMenuOpened?()
        }
    }
}
