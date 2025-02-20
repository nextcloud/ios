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
        
        accountButtonFactory = AccountButtonFactory(controller: controller,
                                                    onAccountDetailsOpen: { [weak self] in self?.collectionViewCommon?.setEditMode(false) },
                                                    presentVC: { [weak self] vc in self?.present(vc, animated: true) },
                                                    onMenuOpened: { [weak self] in self?.collectionViewCommon?.dismissTip() })
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
    
    var accountButtonFactory: AccountButtonFactory!

    override func setNavigationLeftItems() {
        guard let collectionViewCommon else {
            return
        }
        
        if collectionViewCommon.isSearchingMode && (UIDevice.current.userInterfaceIdiom == .phone) {
            navigationItem.leftBarButtonItems = nil
            return
        }
        
        if isCurrentScreenInMainTabBar() {
            navigationItem.leftItemsSupplementBackButton = true
            if navigationController?.viewControllers.count == 1 {
                let burgerMenuItem = UIBarButtonItem(image: UIImage(resource: .BurgerMenu.bars),
                                                     style: .plain,
                                                     action: { [weak self] in
                    self?.mainTabBarController?.showBurgerMenu()
                })
                burgerMenuItem.tintColor = UIColor(resource: .BurgerMenu.navigationBarButton)
                navigationItem.setLeftBarButtonItems([burgerMenuItem], animated: true)
            }
        } else if (collectionViewCommon.layoutKey == NCGlobal.shared.layoutViewRecent) ||
                    (collectionViewCommon.layoutKey == NCGlobal.shared.layoutViewOffline) {
            navigationItem.leftItemsSupplementBackButton = true
            if navigationController?.viewControllers.count == 1 {
                let closeButton = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""),
                                                  style: .plain,
                                                  action: { [weak self] in
                    self?.dismiss(animated: true)
                })
                closeButton.tintColor = NCBrandColor.shared.iconImageColor
                navigationItem.setLeftBarButtonItems([closeButton], animated: true)
            }
        }

        if collectionViewCommon.titlePreviusFolder != nil {
            navigationController?.navigationBar.topItem?.title = collectionViewCommon.titlePreviusFolder
        }

        navigationItem.title = collectionViewCommon.titleCurrentFolder
    }

    override func setNavigationRightItems() {
        guard let collectionViewCommon else {
            return
        }
        
        if collectionViewCommon.isSearchingMode && (UIDevice.current.userInterfaceIdiom == .phone) {
            navigationItem.rightBarButtonItems = nil
            return
        }

        guard collectionViewCommon.layoutKey != NCGlobal.shared.layoutViewTransfers else { return }
        let tabBar = self.tabBarController?.tabBar
        let isTabBarHidden = tabBar?.isHidden ?? true
        let isTabBarSelectHidden = collectionViewCommon.tabBarSelect.isHidden()

        if collectionViewCommon.isEditMode {
            collectionViewCommon.tabBarSelect.update(fileSelect: collectionViewCommon.fileSelect,
                                                     metadatas: collectionViewCommon.getSelectedMetadatas(),
                                                     userId: session.userId)
            collectionViewCommon.tabBarSelect.show()
        } else {
            collectionViewCommon.tabBarSelect.hide()
            navigationItem.rightBarButtonItems = isCurrentScreenInMainTabBar() ? [createAccountButton()] : []
        }
        // fix, if the tabbar was hidden before the update, set it in hidden
        if isTabBarHidden, isTabBarSelectHidden {
            tabBar?.isHidden = true
        }
    }
    
    private func createAccountButton() -> UIBarButtonItem {
        accountButtonFactory.createAccountButton()
    }
}
