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

struct NavigationCollectionViewCommon {
    var serverUrl: String
    var navigationController: UINavigationController?
    var viewController: NCCollectionViewCommon
}

class NCMainTabBarController: UITabBarController {
    var sceneIdentifier: String = UUID().uuidString
    var documentPickerViewController: NCDocumentPickerViewController?
    let navigationCollectionViewCommon = ThreadSafeArray<NavigationCollectionViewCommon>()
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    private var previousIndex: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previousIndex = selectedIndex
    }

    func currentViewController() -> UIViewController? {
        return (selectedViewController as? UINavigationController)?.topViewController
    }

    func currentServerUrl() -> String {
        var serverUrl = NCUtilityFileSystem().getHomeServer(urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
        let viewController = currentViewController()
        if let collectionViewCommon = viewController as? NCCollectionViewCommon {
            if !collectionViewCommon.serverUrl.isEmpty {
                serverUrl = collectionViewCommon.serverUrl
            }
        } else if let media = viewController as? NCMedia {
            serverUrl = media.serverUrl
        } else if let viewerMediaPage = viewController as? NCViewerMediaPage {
            serverUrl = viewerMediaPage.metadatas[viewerMediaPage.currentIndex].serverUrl
        }
        return serverUrl
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
