//
//  NCMainTabBarController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/04/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

import UIKit
import SwiftUI
import NextcloudKit

struct NavigationCollectionViewCommon {
    var serverUrl: String
    var navigationController: UINavigationController?
    var viewController: NCCollectionViewCommon
}

class NCMainTabBarController: UITabBarController {
    var sceneIdentifier: String = UUID().uuidString
    var account = ""
    var availableNotifications: Bool = false
    var documentPickerViewController: NCDocumentPickerViewController?
    let navigationCollectionViewCommon = ThreadSafeArray<NavigationCollectionViewCommon>()
    private var previousIndex: Int?
    private var checkUserDelaultErrorInProgress: Bool = false
    private var timer: Timer?
    private let global = NCGlobal.shared

    var window: UIWindow? {
        return SceneManager.shared.getWindow(controller: self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        NCDownloadAction.shared.setup(sceneIdentifier: sceneIdentifier)

        tabBar.tintColor = NCBrandColor.shared.getElement(account: account)

        // File
        if let item = tabBar.items?[0] {
            item.title = NSLocalizedString("_home_", comment: "")
            item.image = UIImage(systemName: "folder.fill")
            item.selectedImage = item.image
            item.tag = 100
        }

        // Favorite
        if let item = tabBar.items?[1] {
            item.title = NSLocalizedString("_favorites_", comment: "")
            item.image = UIImage(systemName: "star.fill")
            item.selectedImage = item.image
            item.tag = 101
        }

        // Media
        if let item = tabBar.items?[2] {
            item.title = NSLocalizedString("_media_", comment: "")
            item.image = UIImage(systemName: "photo")
            item.selectedImage = item.image
            item.tag = 102
        }

        // Activity
        if let item = tabBar.items?[3] {
            item.title = NSLocalizedString("_activity_", comment: "")
            item.image = UIImage(systemName: "bolt")
            item.selectedImage = item.image
            item.tag = 103
        }

        // More
        if let item = tabBar.items?[4] {
            item.title = NSLocalizedString("_more_", comment: "")
            item.image = UIImage(systemName: "ellipsis")
            item.selectedImage = item.image
            item.tag = 104
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: self.global.notificationCenterChangeTheming), object: nil, queue: .main) { [weak self] notification in
            if let userInfo = notification.userInfo as? NSDictionary,
               let account = userInfo["account"] as? String,
               self?.account == account {
                self?.tabBar.tintColor = NCBrandColor.shared.getElement(account: account)
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: self.global.notificationCenterCheckUserDelaultErrorDone), object: nil, queue: nil) { notification in
            if let userInfo = notification.userInfo,
               let account = userInfo["account"] as? String,
               let controller = userInfo["controller"] as? NCMainTabBarController,
               account == self.account,
               controller == self {
                self.checkUserDelaultErrorInProgress = false
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.timer?.invalidate()
            self.timer = nil
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if !isAppInBackground {
                    self.timerCheck()
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previousIndex = selectedIndex

        if NCBrandOptions.shared.enforce_passcode_lock && NCKeychain().passcode.isEmptyOrNil {
            let vc = UIHostingController(rootView: SetupPasscodeView(isLockActive: .constant(false)))
            vc.isModalInPresentation = true

            present(vc, animated: true)
        }
    }

    private func timerCheck() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false, block: { _ in
            /// Check error
            NCNetworking.shared.checkServerError(account: self.account, controller: self) {
                /// Update right bar button item
                if let navigationController = self.selectedViewController as? NCMainNavigationController {
                    navigationController.updateRightBarButtonItems(self.tabBar.items?[0])
                }
                /// Update Activity tab bar
                if let item = self.tabBar.items?[3] {
                    let capabilities = NCCapabilities.shared.getCapabilities(account: self.account)
                    item.isEnabled = capabilities.capabilityActivityEnabled
                }

                self.timerCheck()
            }
        })
    }

    func currentViewController() -> UIViewController? {
        return (selectedViewController as? UINavigationController)?.topViewController
    }

    func currentServerUrl() -> String {
        let session = NCSession.shared.getSession(account: account)
        var serverUrl = NCUtilityFileSystem().getHomeServer(session: session)
        let viewController = currentViewController()
        if let collectionViewCommon = viewController as? NCCollectionViewCommon {
            if !collectionViewCommon.serverUrl.isEmpty {
                serverUrl = collectionViewCommon.serverUrl
            }
        }
        return serverUrl
    }

    func hide() {
        if #available(iOS 18.0, *) {
            setTabBarHidden(true, animated: true)
        } else {
            tabBar.isHidden = true
        }
    }

    func show() {
        if #available(iOS 18.0, *) {
            setTabBarHidden(false, animated: true)
        } else {
            tabBar.isHidden = false
        }
    }
}

extension NCMainTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if previousIndex == tabBarController.selectedIndex {
            scrollToTop(viewController: viewController)
        }
        previousIndex = tabBarController.selectedIndex
    }

    private func scrollToTop(viewController: UIViewController) {
        guard let navigationController = viewController as? UINavigationController,
              let topViewController = navigationController.topViewController else { return }

        if let scrollView = topViewController.view.subviews.compactMap({ $0 as? UIScrollView }).first {
            scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: true)
        }
    }
}
