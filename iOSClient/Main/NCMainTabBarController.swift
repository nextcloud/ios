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
    private var timerProcess: Timer?
    private let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup)
    private var unauthorizedAccountInProgress: Bool = false
    private var unavailableAccountInProgress: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        if #available(iOS 17.0, *) {
            traitOverrides.horizontalSizeClass = .compact
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil, queue: .main) { [weak self] notification in
            if let userInfo = notification.userInfo as? NSDictionary,
               let account = userInfo["account"] as? String,
               let tabBar = self?.tabBar as? NCMainTabBar,
               self?.account == account {
                let color = NCBrandColor.shared.getElement(account: account)
                tabBar.color = color
                tabBar.tintColor = color
                tabBar.setNeedsDisplay()
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.userDefaultsDidChange()
        }

        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
            self?.userDefaultsDidChange()
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

    private func userDefaultsDidChange() {
        let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup)
        let unauthorizedArray = groupDefaults?.array(forKey: "Unauthorized") as? [String] ?? []
        var unavailableArray = groupDefaults?.array(forKey: "Unavailable") as? [String] ?? []
        let session = NCSession.shared.getSession(account: self.account)

        if unauthorizedArray.contains(account) {
            guard !unauthorizedAccountInProgress else { return }
            unauthorizedAccountInProgress = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkRemoteUser {
                    self.unauthorizedAccountInProgress = false
                }
            }
        } else if unavailableArray.contains(self.account) {
            guard !unavailableAccountInProgress else { return }
            unavailableAccountInProgress = true
            Task {
                let serverUrlFileName = NCUtilityFileSystem().getHomeServer(session: session)
                let options = NKRequestOptions(checkUnauthorized: false)
                let results = await NCNetworking.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: NCKeychain().showHiddenFiles, account: self.account, options: options)
                if results.error == .success {
                    unavailableArray.removeAll { $0 == results.account }
                    groupDefaults?.set(unavailableArray, forKey: "Unavailable")
                } else {
                    NCContentPresenter().showWarning(error: results.error, priority: .max)
                }
                unavailableAccountInProgress = false
            }
        }
    }

    private func checkRemoteUser(completion: @escaping () -> Void = {}) {
        let token = NCKeychain().getPassword(account: account)
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let tableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", account))
        else {
            return completion()
        }

        NCContentPresenter().showCustomMessage(title: "", message: String(format: NSLocalizedString("_account_unauthorized_", comment: ""), account), priority: .high, delay: NCGlobal.shared.dismissAfterSecondLong, type: .error)

        NextcloudKit.shared.getRemoteWipeStatus(serverUrl: tableAccount.urlBase, token: token, account: tableAccount.account) { account, wipe, _, error in
            NCAccount().deleteAccount(account, wipe: wipe)

            if wipe {
                NextcloudKit.shared.setRemoteWipeCompletition(serverUrl: tableAccount.urlBase, token: token, account: tableAccount.account) { _, _, error in
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Set Remote Wipe Completition error code: \(error.errorCode)")
                }
            }

            if let accounts = NCManageDatabase.shared.getAccounts(),
               account.count > 0,
               let account = accounts.first {
                NCAccount().changeAccount(account, userProfile: nil, controller: self) { }
            } else {
                appDelegate.openLogin(selector: NCGlobal.shared.introLogin)
            }

            completion()
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
