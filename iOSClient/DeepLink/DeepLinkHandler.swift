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
    private var appDelegate: AppDelegate? {
        return (UIApplication.shared.delegate as? AppDelegate)
    }
    private var mainTabBarController: NCMainTabBarController? {
        guard let appDelegate, !appDelegate.account.isEmpty else { return nil }
        return appDelegate.window?.rootViewController as? NCMainTabBarController
    }
    
    func parseDeepLink(_ url: URL) -> Bool {
        guard let action = url.host, let deepLink = DeepLink(rawValue: action) else { return false }
        let params = getQueryParamsFromUrl(url: url)
        handleDeepLink(deepLink, params: params)
        return true
    }
    
    func getQueryParamsFromUrl(url: URL) -> [String: Any]? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: Any]()) { (result, item) in
            result[item.name] = item.value
        }
    }
    
    func handleDeepLink(_ deepLink: DeepLink, params:[String: Any]? = nil) {
        switch deepLink {
        case .openFiles:
            navigateTo(index: ControllerConstants.filesIndex)
        case .openFavorites:
            navigateTo(index: ControllerConstants.favouriteIndex)
        case .openMedia:
            navigateTo(index: ControllerConstants.mediaIndex)
        case .openShared:
            navigateToMore(withSegue: ControllerConstants.shares)
        case .openOffline:
            navigateToMore(withSegue: ControllerConstants.offline)
        case .openNotifications:
            navigateToNotification()
        case .openDeleted:
            navigateToMore(withSegue: ControllerConstants.delete)
        case .openSettings:
            navigateToMore(withSegue: ControllerConstants.settings)
        case .openAutoUpload:
            navigateToAutoUpload()
        case .openUrl:
            openUrl(params: params)
        case .createNew:
            navigateToCreateNew()
        case .checkAppUpdate:
            navigateAppUpdate()
        }
    }
    
    private func navigateTo(index: Int) {
        guard let mainTabBarController  else { return }
        mainTabBarController.selectedIndex = index
    }
    
    private func navigateToNotification() {
        guard let mainTabBarController,
              let navigationController = mainTabBarController.viewControllers?[mainTabBarController.selectedIndex] as? UINavigationController,
              let viewController = UIStoryboard(name: ControllerConstants.notification, bundle: nil).instantiateInitialViewController() as? NCNotification else { return }
        navigationController.pushViewController(viewController, animated: true)
    }
    
    private func navigateToCreateNew() {
        guard let mainTabBarController, let appDelegate  else { return }
        appDelegate.toggleMenu(viewController: mainTabBarController)
    }
    
    private func navigateToMore(withSegue segue: String) {
        guard let mainTabBarController  else { return }
        mainTabBarController.selectedIndex = ControllerConstants.moreIndex
        guard let navigationController = mainTabBarController.viewControllers?[mainTabBarController.selectedIndex] as? UINavigationController else { return }
        navigationController.performSegue(withIdentifier: segue, sender: self)
    }
    
    private func navigateToAutoUpload() {
        guard let mainTabBarController  else { return }
        mainTabBarController.selectedIndex = ControllerConstants.moreIndex
        guard let navigationController = mainTabBarController.viewControllers?[mainTabBarController.selectedIndex] as? UINavigationController,
              let moreViewController = navigationController.viewControllers.first,
              let settingViewController = UIStoryboard(name: ControllerConstants.settingIdentifire, bundle: nil).instantiateInitialViewController() else { return }
        let manageAutoUploadVC = CCManageAutoUpload()
        navigationController.setViewControllers([moreViewController, settingViewController, manageAutoUploadVC], animated: true)
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
