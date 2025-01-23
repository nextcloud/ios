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
    private var fileViewController: NCFiles? {
        topViewController as? NCFiles
    }

    private let menuButtonTag = 1
    private let transfersButtonTag = 2
    private let notificationButtonTag = 3

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

            for viewController in self.viewControllers {
                if let rightBarButtonItems = viewController.navigationItem.rightBarButtonItems,
                   let buttonTransfer = rightBarButtonItems.first(where: { $0.tag == self.transfersButtonTag }) {
                    buttonTransfer.tintColor = color
                }
            }
        })

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil, queue: nil) { notification in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.fileViewController?.showTip()
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

    func setNavigationLeftItems() {
        let session = NCSession.shared.getSession(controller: controller)
        guard let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account))
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
                        self.fileViewController?.setEditMode(false)
                    }
                }

                action.subtitle = url
                return action
            }

            let addAccountAction = UIAction(title: NSLocalizedString("_add_account_", comment: ""), image: utility.loadImage(named: "person.crop.circle.badge.plus", colors: NCBrandColor.shared.iconImageMultiColors)) { _ in
                self.appDelegate.openLogin(selector: self.global.introLogin)
            }

            let settingsAccountAction = UIAction(title: NSLocalizedString("_account_settings_", comment: ""), image: utility.loadImage(named: "gear", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                let accountSettingsModel = NCAccountSettingsModel(controller: self.controller, delegate: self.fileViewController)
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
                self.fileViewController?.dismissTip()
            }
        }

        self.fileViewController?.navigationItem.leftItemsSupplementBackButton = true
        self.fileViewController?.navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: accountButton)], animated: true)
    }

    private class AccountSwitcherButton: UIButton {
        var onMenuOpened: (() -> Void)?

        override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
            super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
            onMenuOpened?()
        }
    }

    func setNavigationRightItems() {
        guard let fileViewController else {
            return
        }
        let session = NCSession.shared.getSession(controller: controller)
        let isTabBarHidden = self.tabBarController?.tabBar.isHidden ?? true
        let isTabBarSelectHidden = fileViewController.tabBarSelect.isHidden()

        func createMenuActions() -> [UIMenuElement] {
            guard let layoutForView = database.getLayoutForView(account: session.account, key: fileViewController.layoutKey, serverUrl: fileViewController.serverUrl) else { return [] }

            let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                                  image: utility.loadImage(named: "checkmark.circle"),
                                  attributes: (fileViewController.dataSource.isEmpty() || NCNetworking.shared.isOffline) ? .disabled : []) { _ in
                fileViewController.setEditMode(true)
                fileViewController.collectionView.reloadData()
            }

            let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: utility.loadImage(named: "list.bullet"), state: layoutForView.layout == global.layoutList ? .on : .off) { _ in

                layoutForView.layout = self.global.layoutList

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": fileViewController.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: utility.loadImage(named: "square.grid.2x2"), state: layoutForView.layout == global.layoutGrid ? .on : .off) { _ in

                layoutForView.layout = self.global.layoutGrid

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": fileViewController.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let mediaSquare = UIAction(title: NSLocalizedString("_media_square_", comment: ""), image: utility.loadImage(named: "square.grid.3x3"), state: layoutForView.layout == global.layoutPhotoSquare ? .on : .off) { _ in

                layoutForView.layout = self.global.layoutPhotoSquare

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": fileViewController.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let mediaRatio = UIAction(title: NSLocalizedString("_media_ratio_", comment: ""), image: utility.loadImage(named: "rectangle.grid.3x2"), state: layoutForView.layout == self.global.layoutPhotoRatio ? .on : .off) { _ in

                layoutForView.layout = self.global.layoutPhotoRatio

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": fileViewController.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid, mediaSquare, mediaRatio])

            let ascending = layoutForView.ascending
            let ascendingChevronImage = utility.loadImage(named: ascending ? "chevron.up" : "chevron.down")
            let isName = layoutForView.sort == "fileName"
            let isDate = layoutForView.sort == "date"
            let isSize = layoutForView.sort == "size"

            let byName = UIAction(title: NSLocalizedString("_name_", comment: ""), image: isName ? ascendingChevronImage : nil, state: isName ? .on : .off) { _ in

                if isName { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "fileName"

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": fileViewController.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""), image: isDate ? ascendingChevronImage : nil, state: isDate ? .on : .off) { _ in

                if isDate { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "date"

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": fileViewController.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""), image: isSize ? ascendingChevronImage : nil, state: isSize ? .on : .off) { _ in

                if isSize { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "size"

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": fileViewController.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""), options: .displayInline, children: [byName, byNewest, byLargest])

            let foldersOnTop = UIAction(title: NSLocalizedString("_directory_on_top_no_", comment: ""), image: utility.loadImage(named: "folder"), state: layoutForView.directoryOnTop ? .on : .off) { _ in

                layoutForView.directoryOnTop = !layoutForView.directoryOnTop

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": fileViewController.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let personalFilesOnly = NCKeychain().getPersonalFilesOnly(account: session.account)
            let personalFilesOnlyAction = UIAction(title: NSLocalizedString("_personal_files_only_", comment: ""), image: utility.loadImage(named: "folder.badge.person.crop", colors: NCBrandColor.shared.iconImageMultiColors), state: personalFilesOnly ? .on : .off) { _ in

                NCKeychain().setPersonalFilesOnly(account: session.account, value: !personalFilesOnly)

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": fileViewController.serverUrl, "clearDataSource": true])
                self.setNavigationRightItems()
            }

            let showDescriptionKeychain = NCKeychain().showDescription
            let showDescription = UIAction(title: NSLocalizedString("_show_description_", comment: ""), attributes: fileViewController.richWorkspaceText == nil ? .disabled : [], state: showDescriptionKeychain && fileViewController.richWorkspaceText != nil ? .on : .off) { _ in

                NCKeychain().showDescription = !showDescriptionKeychain

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": fileViewController.serverUrl, "clearDataSource": true])
                self.setNavigationRightItems()
            }

            showDescription.subtitle = fileViewController.richWorkspaceText == nil ? NSLocalizedString("_no_description_available_", comment: "") : ""

            let showRecommendedFilesKeychain = NCKeychain().showRecommendedFiles
            let capabilityRecommendations = NCCapabilities.shared.getCapabilities(account: session.account).capabilityRecommendations
            let showRecommendedFiles = UIAction(title: NSLocalizedString("_show_recommended_files_", comment: ""), attributes: !capabilityRecommendations ? .disabled : [], state: showRecommendedFilesKeychain ? .on : .off) { _ in

                NCKeychain().showRecommendedFiles = !showRecommendedFilesKeychain

                fileViewController.collectionView.reloadData()
                self.setNavigationRightItems()
            }

            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop, personalFilesOnlyAction, showDescription, showRecommendedFiles])

            return [select, viewStyleSubmenu, sortSubmenu, additionalSubmenu]
        }

        if fileViewController.isEditMode {
            fileViewController.tabBarSelect.update(fileSelect: fileViewController.fileSelect, metadatas: fileViewController.getSelectedMetadatas(), userId: session.userId)
            fileViewController.tabBarSelect.show()

            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                fileViewController.setEditMode(false)
                fileViewController.collectionView.reloadData()
            }

            self.fileViewController?.navigationItem.rightBarButtonItems = [select]
        } else if self.fileViewController?.navigationItem.rightBarButtonItems == nil || (!fileViewController.isEditMode && !fileViewController.tabBarSelect.isHidden()) {
            fileViewController.tabBarSelect.hide()

            let menuButton = UIBarButtonItem(image: utility.loadImage(named: "ellipsis.circle"), menu: UIMenu(children: createMenuActions()))
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
                    viewController.session = session
                    self.pushViewController(viewController, animated: true)
                }
            }

            notificationButton.tintColor = NCBrandColor.shared.iconImageColor
            notificationButton.tag = notificationButtonTag

            self.fileViewController?.navigationItem.rightBarButtonItems = [menuButton, notificationButton, transfersButton]
        } else {
            self.fileViewController?.navigationItem.rightBarButtonItems?.first?.menu = self.fileViewController?.navigationItem.rightBarButtonItems?.first?.menu?.replacingChildren(createMenuActions())
        }

        // fix, if the tabbar was hidden before the update, set it in hidden
        if isTabBarHidden, isTabBarSelectHidden {
            self.tabBarController?.tabBar.isHidden = true
        }
    }
}
