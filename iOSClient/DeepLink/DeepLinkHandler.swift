//
//  DeepLinkHandler.swift
//  Nextcloud
//
//  Created by Amrut Waghmare on 29/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

enum ControllerConstants {
    static let filesIndex = 0
    static let favouriteIndex = 1
    static let mediaIndex = 3
    static let moreIndex = 4
    static let notification = "NCNotification"
    static let settings = "segueSettings"
    static let shares = "segueShares"
    static let offline = "segueOffline"
    static let delete = "segueTrash"
    static let settingIdentifire = "NCSettings"
}
class DeepLinkHandler {
    
    func parseDeepLink(_ url: URL, mainTabBarController: NCMainTabBarController) {
        guard let action = url.host, let deepLink = DeepLink(rawValue: action) else { return }
        let params = getQueryParamsFromUrl(url: url)
        handleDeepLink(deepLink, mainTabBarController: mainTabBarController, params: params)
    }
    
    func getQueryParamsFromUrl(url: URL) -> [String: Any]? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: Any]()) { (result, item) in
            result[item.name] = item.value
        }
    }
    
    func handleDeepLink(_ deepLink: DeepLink, mainTabBarController: NCMainTabBarController, params:[String: Any]? = nil) {
        switch deepLink {
        case .openFiles:
            navigateTo(index: ControllerConstants.filesIndex, mainTabBarController: mainTabBarController)
        case .openFavorites:
            navigateTo(index: ControllerConstants.favouriteIndex, mainTabBarController: mainTabBarController)
        case .openMedia:
            navigateTo(index: ControllerConstants.mediaIndex, mainTabBarController: mainTabBarController)
        case .openShared:
            navigateToMore(withSegue: ControllerConstants.shares, mainTabBarController: mainTabBarController)
        case .openOffline:
            navigateToMore(withSegue: ControllerConstants.offline, mainTabBarController: mainTabBarController)
        case .openNotifications:
            navigateToNotification(mainTabBarController: mainTabBarController)
        case .openDeleted:
            navigateToMore(withSegue: ControllerConstants.delete, mainTabBarController: mainTabBarController)
        case .openSettings:
            navigateToMore(withSegue: ControllerConstants.settings, mainTabBarController: mainTabBarController)
        case .openAutoUpload:
            navigateToAutoUpload(mainTabBarController: mainTabBarController)
        case .openUrl:
            openUrl(params: params)
        case .createNew:
            navigateToCreateNew(mainTabBarController: mainTabBarController)
        case .checkAppUpdate:
            navigateAppUpdate()
        }
    }
    
    private func navigateTo(index: Int,mainTabBarController: NCMainTabBarController) {
        mainTabBarController.selectedIndex = index
    }
    
    private func navigateToNotification(mainTabBarController: NCMainTabBarController) {
        mainTabBarController.selectedIndex = ControllerConstants.filesIndex
        guard let navigationController = mainTabBarController.viewControllers?[mainTabBarController.selectedIndex] as? UINavigationController,
              let viewController = UIStoryboard(name: ControllerConstants.notification, bundle: nil).instantiateInitialViewController() as? NCNotification else { return }
        navigationController.pushViewController(viewController, animated: true)
    }
    
    private func navigateToCreateNew(mainTabBarController: NCMainTabBarController) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        mainTabBarController.selectedIndex = ControllerConstants.filesIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            appDelegate.toggleMenu(mainTabBarController: mainTabBarController)
        }
    }
    
    private func navigateToMore(withSegue segue: String, mainTabBarController: NCMainTabBarController) {
        mainTabBarController.selectedIndex = ControllerConstants.moreIndex
        guard let navigationController = mainTabBarController.viewControllers?[mainTabBarController.selectedIndex] as? UINavigationController else { return }
        navigationController.viewControllers = navigationController.viewControllers.filter({$0.isKind(of: NCMore.self)})
        navigationController.performSegue(withIdentifier: segue, sender: self)
    }
    
    private func navigateToAutoUpload(mainTabBarController: NCMainTabBarController) {
        mainTabBarController.selectedIndex = ControllerConstants.moreIndex
        guard let navigationController = mainTabBarController.viewControllers?[mainTabBarController.selectedIndex] as? UINavigationController,
              let moreViewController = navigationController.viewControllers.first,
              let settingViewController = UIStoryboard(name: ControllerConstants.settingIdentifire, bundle: nil).instantiateInitialViewController() else { return }
        let manageAutoUploadVC = CCManageAutoUpload()
        navigationController.viewControllers = navigationController.viewControllers.filter({$0.isKind(of: NCMore.self)})
        navigationController.setViewControllers([settingViewController, manageAutoUploadVC], animated: true)
    }
    
    private func navigateAppUpdate() {
        guard let url = URL(string: NCBrandOptions.shared.appStoreUrl) else { return }
        handleUrl(url: url)
    }
    
    private func openUrl(params: [String: Any]?) {
        guard let urlString = params?["url"] as? String, let url = URL(string: urlString) else { return }
        handleUrl(url: url)
    }
    
    private func handleUrl(url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
