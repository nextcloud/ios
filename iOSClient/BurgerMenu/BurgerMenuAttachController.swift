//
//  BurgerMenuAttachController.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 28.07.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation

class BurgerMenuAttachController {
    private weak var presentingScreen: UIViewController?
    private var sideMenu: BurgerMenuViewController?
    
    init(with presentingViewController: UIViewController) {
        self.presentingScreen = presentingViewController
    }
    
    func showMenu() {
        sideMenu = BurgerMenuViewController(delegate: self)
        guard let sideMenu = sideMenu else {
            return
        }
        sideMenu.modalPresentationStyle = .overFullScreen
        presentingScreen?.present(sideMenu, animated: false)
    }
}

extension BurgerMenuAttachController: BurgerMenuViewModelDelegate {
    func burgerMenuViewModelDidHideMenu(_ viewModel: BurgerMenuViewModel) {
        sideMenu?.dismiss(animated: false)
    }
    
    func burgerMenuViewModelWantsOpenRecent(_ viewModel: BurgerMenuViewModel) {
        sideMenu?.dismiss(animated: false)
        let storyboard = UIStoryboard(name: "NCRecent", bundle: nil)
        present(vc: storyboard.instantiateInitialViewController())
    }
    
    func burgerMenuViewModelWantsOpenOffline(_ viewModel: BurgerMenuViewModel) {
        sideMenu?.dismiss(animated: false)
        let storyboard = UIStoryboard(name: "NCOffline", bundle: nil)
        present(vc: storyboard.instantiateInitialViewController())
    }
    
    func burgerMenuViewModelWantsOpenDeletedFiles(_ viewModel: BurgerMenuViewModel) {
        sideMenu?.dismiss(animated: false)
        let storyboard = UIStoryboard(name: "NCTrash", bundle: nil)
        present(vc: storyboard.instantiateInitialViewController())
    }
    
    func burgerMenuViewModelWantsOpenSettings(_ viewModel: BurgerMenuViewModel) {
        sideMenu?.dismiss(animated: false)
        let storyboard = UIStoryboard(name: "NCSettings", bundle: nil)
        present(vc: storyboard.instantiateInitialViewController())
    }
    
    private func present(vc: UIViewController?) {
        guard let vc = vc else {
            return
        }
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .overCurrentContext
        navVC.setNavigationBarAppearance()
        presentingScreen?.present(navVC, animated: true)
    }
}
