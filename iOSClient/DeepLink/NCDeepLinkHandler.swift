// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Amrut Waghmare
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
    static let mediaIndex = 2
    static let activityIndex = 3
    static let moreIndex = 4
    static let notification = "NCNotification"
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
            Task { @MainActor in
                navigateToMore(destination: .storyboard(name: "NCShares", presentation: .push), controller: controller)
            }
        case .openOffline:
            Task { @MainActor in
                navigateToMore(destination: .storyboard(name: "NCOffline", presentation: .push), controller: controller)
            }
        case .openDeleted:
            Task { @MainActor in
                navigateToMore(destination: .storyboard(name: "NCTrash", presentation: .push), controller: controller)
            }
        case .openNotifications:
            navigateToNotification(controller: controller)
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
        if let navigationController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? UINavigationController,
           let viewController = navigationController.topViewController as? NCNotification {
            viewController.modalPresentationStyle = .pageSheet
            viewController.session = NCSession.shared.getSession(controller: controller)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                controller.present(navigationController, animated: true, completion: nil)
            }
        }
    }

    private func navigateToCreateNew(controller: NCMainTabBarController) {
        controller.selectedIndex = ControllerConstants.filesIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            let serverUrl = controller.currentServerUrl()
            let session = NCSession.shared.getSession(controller: controller)
            let fileFolderPath = NCUtilityFileSystem().getRelativeFilePath("", serverUrl: serverUrl, session: session)
            let fileFolderName = (serverUrl as NSString).lastPathComponent
            let capabilities = NCNetworking.shared.capabilities[controller.account] ?? NKCapabilities.Capabilities()

            if !FileNameValidator.checkFolderPath(fileFolderPath, account: controller.account, capabilities: capabilities) {
                controller.present(UIAlertController.warning(message: "\(String(format: NSLocalizedString("_file_name_validator_error_reserved_name_", comment: ""), fileFolderName)) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)

                return
            }
            // appDelegate.toggleMenu(controller: controller, sender: nil)
        }
    }

    @MainActor
    private func navigateToMore(destination: NCMoreModel.Destination, controller: NCMainTabBarController) {
        controller.selectedIndex = ControllerConstants.moreIndex
        guard let navigationController = controller.viewControllers?[controller.selectedIndex] as? UINavigationController else {
            return
        }

        navigationController.popToRootViewController(animated: false)

        let model = NCMoreModel(controller: controller)

        model.perform(destination)
    }

    private func navigateToSettings(controller: NCMainTabBarController) {
        controller.selectedIndex = ControllerConstants.moreIndex
        guard let navigationController = controller.viewControllers?[controller.selectedIndex] as? UINavigationController else { return }

        Task { @MainActor in
            navigationController.popToRootViewController(animated: false)

            let settingsView = NCSettingsView(model: NCSettingsModel(controller: controller))
            let settingsController = UIHostingController(rootView: settingsView)
            settingsController.title = NSLocalizedString("_settings_", comment: "")
            navigationController.pushViewController(settingsController, animated: true)
        }
    }

    private func navigateToAutoUpload(controller: NCMainTabBarController) {
        controller.selectedIndex = ControllerConstants.moreIndex
        guard let navigationController = controller.viewControllers?[controller.selectedIndex] as? UINavigationController else { return }

        Task { @MainActor in
            navigationController.popToRootViewController(animated: false)

            let autoUploadView = NCAutoUploadView(model: NCAutoUploadModel(controller: controller), albumModel: AlbumModel(controller: controller))
            let autoUploadController = UIHostingController(rootView: autoUploadView)
            navigationController.pushViewController(autoUploadController, animated: true)
        }
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
