// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

class NCMainNavigationController: UINavigationController {
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    let utility = NCUtility()
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    var collectionViewCommon: NCCollectionViewCommon? {
        topViewController as? NCCollectionViewCommon
    }

    let menuButtonTag = 1
    let transfersButtonTag = 2
    let notificationButtonTag = 3

    override func viewDidLoad() {
        super.viewDidLoad()

        setNavigationBarAppearance()
        navigationBar.prefersLargeTitles = true
        setNavigationBarHidden(false, animated: true)
    }

    func setNavigationLeftItems() { }
    func setNavigationRightItems() { }
}
