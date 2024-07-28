//
//  BurgerMenuAttachController.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 28.07.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation

class BurgerMenuAttachController {
    private let sideMenuSlidingVelocity = 0.5
    private let sideMenuSlidingDamping: CGFloat = 0.9
    
    private weak var presentingScreen: UIViewController?
    private var sideMenu: BurgerMenuViewController?
    private var sideMenuTrailing: NSLayoutConstraint!
    private var isDisplayingMenu: Bool = false
    
    func showMenu() {
        showSideMenu()
    }
    
    func hideMenu(){
        hideSideMenu()
    }
    
    init(with presentingViewController: UIViewController) {
        self.presentingScreen = presentingViewController
        setupSideMenu()
    }
    
    private func setupSideMenu() {
        if let presentingView = presentingScreen?.view {
            let menuVC = BurgerMenuViewController(rootView: BurgerMenuView(delegate: self))
            
            menuVC.view.frame = presentingView.bounds
            presentingView.addSubview(menuVC.view)
            
            if let menu = menuVC.view {
                menu.translatesAutoresizingMaskIntoConstraints = false
                
                let widthConstraint = menu.widthAnchor.constraint(equalTo: presentingView.widthAnchor)
                sideMenuTrailing = menu.trailingAnchor.constraint(equalTo: presentingView.leadingAnchor)
                let bottomConstraint = menu.bottomAnchor.constraint(equalTo: presentingView.bottomAnchor)
                let topConstraint = menu.topAnchor.constraint(equalTo: presentingView.topAnchor)
                
                let constraints = [sideMenuTrailing!, topConstraint, widthConstraint, bottomConstraint]
                
                presentingView.addConstraints(constraints)
                NSLayoutConstraint.activate(constraints)
                
                menu.alpha = 0
                
            }
            
            sideMenu = menuVC
            
        }
    }
    
    //MARK: - private
    private func showSideMenu() {
        isDisplayingMenu.toggle()
        animate(action: { [weak self] in
            if let sideMenu = self?.sideMenu,
               let menuTrailing = self?.sideMenuTrailing {
                sideMenu.view.alpha = 1
                menuTrailing.constant = sideMenu.view.bounds.width
            }
        })
    }
    
    private func hideSideMenu() {
        isDisplayingMenu.toggle()
        animate(action:   { [weak self] in
            if let menu = self?.sideMenu?.view,
               let menuTrailing = self?.sideMenuTrailing {
                menu.alpha = 0
                menuTrailing.constant = 0
            }
        })
    }
    
    private func animate(action: @escaping () -> (), completion: ((Bool) -> Void)? = nil) {
        presentingScreen?.view.layoutIfNeeded()
        UIView.animate(withDuration: sideMenuSlidingVelocity,
                       delay: 0,
                       usingSpringWithDamping: sideMenuSlidingDamping,
                       initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            [weak self] in
            action()
            self?.presentingScreen?.view.layoutIfNeeded()
        }, completion: completion)
    }
}

extension BurgerMenuAttachController: BurgerMenuViewDelegate {
    func moveBack() {
        hideMenu()
    }
    
    func openRecent() {
        let storyboard = UIStoryboard(name: "NCRecent", bundle: nil)
        guard let ncRecent = storyboard.instantiateInitialViewController() else {
            return
        }
        let navVC = UINavigationController(rootViewController: ncRecent)
        presentingScreen?.present(navVC, animated: true)
    }
    
    func openOffline() {
        let storyboard = UIStoryboard(name: "NCOffline", bundle: nil)
        guard let ncRecent = storyboard.instantiateInitialViewController() else {
            return
        }
        let navVC = UINavigationController(rootViewController: ncRecent)
        presentingScreen?.present(navVC, animated: true)
    }
    
    func openDeletedFiles() {
        let storyboard = UIStoryboard(name: "NCTrash", bundle: nil)
        guard let ncRecent = storyboard.instantiateInitialViewController() else {
            return
        }
        let navVC = UINavigationController(rootViewController: ncRecent)
        presentingScreen?.present(navVC, animated: true)
    }
    
    func openSettings() {
        let storyboard = UIStoryboard(name: "NCSettings", bundle: nil)
        guard let ncRecent = storyboard.instantiateInitialViewController() else {
            return
        }
        let navVC = UINavigationController(rootViewController: ncRecent)
        presentingScreen?.present(navVC, animated: true)
    }
}
