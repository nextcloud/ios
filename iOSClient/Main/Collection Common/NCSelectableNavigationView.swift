//
//  NCSelectableNavigationView.swift
//  Nextcloud
//
//  Created by Henrik Storch on 27.01.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

import NextcloudKit
import Realm
import UIKit

extension RealmSwiftObject {
    var primaryKeyValue: String? {
        guard let primaryKeyName = self.objectSchema.primaryKeyProperty?.name else { return nil }
        return value(forKey: primaryKeyName) as? String
    }
}

public protocol NCSelectableViewTabBar {
    var tabBarController: UITabBarController? { get }
    var hostingController: UIViewController? { get }
}

protocol NCSelectableNavigationView: AnyObject {
    var viewController: UIViewController { get }
    var appDelegate: AppDelegate { get }
    var selectableDataSource: [RealmSwiftObject] { get }
    var collectionView: UICollectionView! { get set }
    var isEditMode: Bool { get set }
    var selectOcId: [String] { get set }
    var titleCurrentFolder: String { get }
    var navigationItem: UINavigationItem { get }
    var navigationController: UINavigationController? { get }
    var layoutKey: String { get }
    var serverUrl: String { get }
    var tabBarSelect: NCSelectableViewTabBar? { get set }

    func reloadDataSource(withQueryDB: Bool)
    func setNavigationLeftItems()
    func setNavigationRightItems(enableMenu: Bool)
    func createMenuActions() -> [UIMenuElement]

    func toggleSelect(isOn: Bool?)
    func onListSelected()
    func onGridSelected()
}

extension NCSelectableNavigationView {
    func setNavigationLeftItems() {}

    func saveLayout(_ layoutForView: NCDBLayoutForView) {
        NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
        setNavigationRightItems(enableMenu: false)
    }

    /// If explicit `isOn` is not set, it will invert `isEditMode`
    func toggleSelect(isOn: Bool? = nil) {
        DispatchQueue.main.async {
            self.isEditMode = isOn ?? !self.isEditMode
            self.selectOcId.removeAll()
            self.setNavigationLeftItems()
            self.setNavigationRightItems(enableMenu: true)
            self.collectionView.reloadData()
        }
    }

    func collectionViewSelectAll() {
        selectOcId = selectableDataSource.compactMap({ $0.primaryKeyValue })
        collectionView.reloadData()
        setNavigationRightItems(enableMenu: false)
    }

    func tapNotification() {
        if let viewController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? NCNotification {
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
}

extension NCSelectableNavigationView where Self: UIViewController {
    var viewController: UIViewController {
        self
    }
}
