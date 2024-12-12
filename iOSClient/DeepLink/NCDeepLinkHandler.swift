//
//  DeepLinkHandler.swift
//  Nextcloud
//
//  Created by Amrut Waghmare on 29/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit
import SwiftUI
import NextcloudKit

enum DeepLink: String {
    case openFiles              // nextcloud://openFiles
    case openFavorites          // nextcloud://openFavorites
    case openMedia              // nextcloud://openMedia
    case openShared             // nextcloud://openShared
    case openOffline            // nextcloud://openOffline
    case openNotifications      // nextcloud://openNotifications
    case openDeleted            // nextcloud://openDeleted
    case openSettings           // nextcloud://openSettings
    case openAutoUpload         // nextcloud://openAutoUpload
    case openUrl                // nextcloud://openUrl?url=https://nextcloud.com
    case createNew              // nextcloud://createNew
    case checkAppUpdate         // nextcloud://checkAppUpdate
}

enum ControllerConstants {
    static let filesIndex = 0
    static let favouriteIndex = 1
    static let mediaIndex = 3
    static let moreIndex = 4
    static let notification = "NCNotification"
    static let shares = "segueShares"
    static let offline = "segueOffline"
    static let delete = "segueTrash"
}

class NCDeepLinkHandler {
    func parseDeepLink(_ url: URL, controller: NCMainTabBarController) {
        guard let action = url.host, let deepLink = DeepLink(rawValue: action) else { return }
        let params = getQueryParamsFromUrl(url: url)
        handleDeepLink(deepLink, controller: controller, params: params)
    }

    func getQueryParamsFromUrl(url: URL) -> [String: Any]? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: Any]()) { result, item in
            result[item.name] = item.value
        }
    }

    func handleDeepLink(_ deepLink: DeepLink, controller: NCMainTabBarController, params: [String: Any]? = nil) {
        switch deepLink {
        case .openFiles:
            navigateTo(index: ControllerConstants.filesIndex, controller: controller)
        case .openFavorites:
            navigateTo(index: ControllerConstants.favouriteIndex, controller: controller)
        case .openMedia:
            navigateTo(index: ControllerConstants.mediaIndex, controller: controller)
        case .openShared:
            navigateToMore(withSegue: ControllerConstants.shares, controller: controller)
        case .openOffline:
            navigateToMore(withSegue: ControllerConstants.offline, controller: controller)
        case .openNotifications:
            navigateToNotification(controller: controller)
        case .openDeleted:
            navigateToMore(withSegue: ControllerConstants.delete, controller: controller)
        case .openSettings:
            navigateToSettings(controller: controller)
        case .openAutoUpload:
            navigateToAutoUpload(controller: controller)
        case .openUrl:
            openUrl(params: params)
        case .createNew:
            navigateToCreateNew(controller: controller)
        case .checkAppUpdate:
            navigateAppUpdate()
        }
    }

    private func navigateTo(index: Int, controller: NCMainTabBarController) {
        controller.selectedIndex = index
    }

    private func navigateToNotification(controller: NCMainTabBarController) {
        controller.selectedIndex = ControllerConstants.filesIndex
        guard let navigationController = controller.viewControllers?[controller.selectedIndex] as? UINavigationController,
              let viewController = UIStoryboard(name: ControllerConstants.notification, bundle: nil).instantiateInitialViewController() as? NCNotification else { return }
        viewController.session = NCSession.shared.getSession(controller: controller)
        navigationController.pushViewController(viewController, animated: true)
    }

    private func navigateToCreateNew(controller: NCMainTabBarController) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        controller.selectedIndex = ControllerConstants.filesIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            let serverUrl = controller.currentServerUrl()
            let session = NCSession.shared.getSession(controller: controller)
            let fileFolderPath = NCUtilityFileSystem().getFileNamePath("", serverUrl: serverUrl, session: session)
            let fileFolderName = (serverUrl as NSString).lastPathComponent

            if !FileNameValidator.shared.checkFolderPath(fileFolderPath, account: controller.account) {
                controller.present(UIAlertController.warning(message: "\(String(format: NSLocalizedString("_file_name_validator_error_reserved_name_", comment: ""), fileFolderName)) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)

                return
            }

            appDelegate.toggleMenu(controller: controller)
        }
    }

    private func navigateToMore(withSegue segue: String, controller: NCMainTabBarController) {
        controller.selectedIndex = ControllerConstants.moreIndex
        guard let navigationController = controller.viewControllers?[controller.selectedIndex] as? UINavigationController else { return }
        navigationController.viewControllers = navigationController.viewControllers.filter({$0.isKind(of: NCMore.self)})
        navigationController.performSegue(withIdentifier: segue, sender: self)
    }

    private func navigateToSettings(controller: NCMainTabBarController) {
        controller.selectedIndex = ControllerConstants.moreIndex
        guard let navigationController = controller.viewControllers?[controller.selectedIndex] as? UINavigationController else { return }

        let settingsView = NCSettingsView(model: NCSettingsModel(controller: controller))
        let settingsController = UIHostingController(rootView: settingsView)
        navigationController.pushViewController(settingsController, animated: true)
    }

    private func navigateToAutoUpload(controller: NCMainTabBarController) {
        controller.selectedIndex = ControllerConstants.moreIndex
        guard let navigationController = controller.viewControllers?[controller.selectedIndex] as? UINavigationController else { return }

        let autoUploadView = NCAutoUploadView(model: NCAutoUploadModel(controller: controller))
        let autoUploadController = UIHostingController(rootView: autoUploadView)
        navigationController.pushViewController(autoUploadController, animated: true)
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
