//
//  HiDriveMainNavigationController.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 20.02.2025.
//  Copyright © 2025 STRATO GmbH. All rights reserved.
//

import UIKit

class HiDriveMainNavigationController: UINavigationController, UINavigationControllerDelegate {
    
    var accountButtonFactory: AccountButtonFactory!
    
    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }
    
    var collectionViewCommon: NCCollectionViewCommon? {
        topViewController as? NCCollectionViewCommon
    }
    
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        setNavigationBarAppearance()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
        navigationBar.prefersLargeTitles = false
        setNavigationBarHidden(false, animated: true)
        
        accountButtonFactory = AccountButtonFactory(controller: controller,
                                                    onAccountDetailsOpen: { [weak self] in self?.collectionViewCommon?.setEditMode(false) },
                                                    presentVC: { [weak self] vc in self?.present(vc, animated: true) },
                                                    onMenuOpened: { [weak self] in self?.collectionViewCommon?.dismissTip() })
    }
    
    func setNavigationLeftItems() {
        guard let collectionViewCommon else {
            return
        }
        
        if collectionViewCommon.isSearchingMode && (UIDevice.current.userInterfaceIdiom == .phone) {
            collectionViewCommon.navigationItem.leftBarButtonItems = nil
            return
        }
        
        if isCurrentScreenInMainTabBar() {
            collectionViewCommon.navigationItem.leftItemsSupplementBackButton = true
            if viewControllers.count == 1 {
                let burgerMenuItem = UIBarButtonItem(image: UIImage(resource: .BurgerMenu.bars),
                                                     style: .plain,
                                                     action: { [weak self] in
                    self?.mainTabBarController?.showBurgerMenu()
                })
                burgerMenuItem.tintColor = UIColor(resource: .BurgerMenu.navigationBarButton)
                collectionViewCommon.navigationItem.setLeftBarButtonItems([burgerMenuItem], animated: true)
            }
        } else if (collectionViewCommon.layoutKey == NCGlobal.shared.layoutViewRecent) ||
                    (collectionViewCommon.layoutKey == NCGlobal.shared.layoutViewOffline) {
            collectionViewCommon.navigationItem.leftItemsSupplementBackButton = true
            if viewControllers.count == 1 {
                let closeButton = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""),
                                                  style: .plain,
                                                  action: { [weak self] in
                    self?.dismiss(animated: true)
                })
                closeButton.tintColor = NCBrandColor.shared.iconImageColor
                collectionViewCommon.navigationItem.setLeftBarButtonItems([closeButton], animated: true)
            }
        }
    }
    
    func setNavigationRightItems() {
        guard let collectionViewCommon else {
            return
        }
        
        if collectionViewCommon.isSearchingMode && (UIDevice.current.userInterfaceIdiom == .phone) {
            collectionViewCommon.navigationItem.rightBarButtonItems = nil
            return
        }
        
        guard collectionViewCommon.layoutKey != NCGlobal.shared.layoutViewTransfers else { return }
        
        if collectionViewCommon.isEditMode {
            collectionViewCommon.tabBarSelect?.update(fileSelect: collectionViewCommon.fileSelect,
                                                     metadatas: collectionViewCommon.getSelectedMetadatas(),
                                                     userId: session.userId)
            collectionViewCommon.tabBarSelect?.show()
        } else {
            collectionViewCommon.tabBarSelect?.hide()
            collectionViewCommon.navigationItem.rightBarButtonItems = isCurrentScreenInMainTabBar() ? [createAccountButton()] : []
        }
    }
    
    private func createAccountButton() -> UIBarButtonItem {
        accountButtonFactory.createAccountButton()
    }
}
