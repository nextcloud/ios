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

class NCMainTabBarController: UITabBarController {
    var sceneIdentifier: String = UUID().uuidString
    var documentPickerViewController: NCDocumentPickerViewController?
    let filesServerUrl = ThreadSafeDictionary<String, NCFiles>()

    func currentViewController() -> UIViewController? {
        return (selectedViewController as? UINavigationController)?.topViewController
    }

    func currentServerUrl() -> String {
        guard let domain = NCDomain.shared.getActiveDomain() else { return "" }
        var serverUrl = NCUtilityFileSystem().getHomeServer(domain: domain)
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
