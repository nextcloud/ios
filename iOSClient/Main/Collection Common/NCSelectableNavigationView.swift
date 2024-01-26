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

protocol NCSelectableNavigationView: AnyObject {

    var appDelegate: AppDelegate { get }
    var selectableDataSource: [RealmSwiftObject] { get }
    var collectionView: UICollectionView! { get set }
    var isEditMode: Bool { get set }
    var selectOcId: [String] { get set }
    var selectIndexPath: [IndexPath] { get set }
    var titleCurrentFolder: String { get }
    var navigationItem: UINavigationItem { get }
    var navigationController: UINavigationController? { get }
    var layoutKey: String { get }
    var selectActions: [NCMenuAction] { get }

    func reloadDataSource(withQueryDB: Bool)
    func setNavigationItems()

    func tapSelectMenu()
    func tapSelect()
}

extension NCSelectableNavigationView {

    func setNavigationItems() {
        setNavigationRightItems()
    }

    func setNavigationRightItems() {
        if isEditMode {
            let more = UIBarButtonItem(image: .init(systemName: "ellipsis"), style: .plain, action: tapSelectMenu)
            navigationItem.rightBarButtonItems = [more]
        } else {
            //            let select = UIBarButtonItem(title: NSLocalizedString("_select_", comment: ""), style: UIBarButtonItem.Style.plain, action: tapSelect)
            let notification = UIBarButtonItem(image: .init(systemName: "bell"), style: .plain, action: tapNotification)
            //            if layoutKey == NCGlobal.shared.layoutViewFiles {
            //                navigationItem.rightBarButtonItems = [select, notification]
            //            } else {
            //                navigationItem.rightBarButtonItems = [select]
            //            }

            let menu = UIMenu(children: createMenuActions())
            let menuButton = UIBarButtonItem(image: .init(systemName: "ellipsis.circle"), menu: menu)

            if layoutKey == NCGlobal.shared.layoutViewFiles {
                navigationItem.rightBarButtonItems = [menuButton, notification]
            } else {
                navigationItem.rightBarButtonItems = [menuButton]
            }

            //            navigationItem.rightBarButtonItems = [menuButton]
        }
    }

    private func createMenuActions() -> [UIMenuElement] {
        let select = UIAction(title: NSLocalizedString("_select_", comment: ""), image: .init(systemName: "checkmark.circle")) { _ in self.tapSelectMenu() }

        let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: .init(systemName: "list.bullet")) { _ in self.tapSelectMenu() }
        let grid = UIAction(title: NSLocalizedString("_grid_", comment: ""), image: .init(systemName: "square.grid.2x2")) { _ in self.tapSelectMenu() }

        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid])

        let byName = UIAction(title: NSLocalizedString("_order_by_name_a_z_", comment: ""), image: nil) { _ in self.tapSelectMenu() }
        let byNewest = UIAction(title: NSLocalizedString("_order_by_date_more_recent_", comment: ""), image: nil) { _ in self.tapSelectMenu() }
        let byLargest = UIAction(title: NSLocalizedString("_order_by_size_smallest_", comment: ""), image: nil) { _ in self.tapSelectMenu() }

        let sortSubmenu = UIMenu(title: "", options: .displayInline, children: [byName, byNewest, byLargest])

        let foldersOnTop = UIAction(title: NSLocalizedString("_directory_on_top_no_", comment: ""), image: nil) { _ in self.tapSelectMenu() }

        let foldersSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop])

        return [select, viewStyleSubmenu, sortSubmenu, foldersSubmenu]
    }

    func tapSelect() {
        isEditMode = !isEditMode
        selectOcId.removeAll()
        selectIndexPath.removeAll()
        self.setNavigationItems()
        self.collectionView.reloadData()
    }

    func collectionViewSelectAll() {
        selectOcId = selectableDataSource.compactMap({ $0.primaryKeyValue })
        collectionView.reloadData()
    }

    func tapNotification() {
        if let viewController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? NCNotification {
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
}

extension NCSelectableNavigationView where Self: UIViewController {
    func tapSelectMenu() {
        presentMenu(with: selectActions)
    }

    var selectActions: [NCMenuAction] {
        var actions = [NCMenuAction]()

        actions.append(.cancelAction {
            self.tapSelect()
        })
        if selectOcId.count != selectableDataSource.count {
            actions.append(.selectAllAction(action: collectionViewSelectAll))
        }

        guard !selectOcId.isEmpty else { return actions }

        actions.append(.seperator(order: 0))

        var selectedMetadatas: [tableMetadata] = []
        var selectedMediaMetadatas: [tableMetadata] = []
        var isAnyOffline = false
        var isAnyFolder = false
        var isAnyLocked = false
        var canUnlock = true

        for ocId in selectOcId {
            guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { continue }
            selectedMetadatas.append(metadata)
            if [NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue].contains(metadata.classFile) {
                selectedMediaMetadatas.append(metadata)
            }
            if metadata.directory { isAnyFolder = true }
            if metadata.lock {
                isAnyLocked = true
                if metadata.lockOwner != appDelegate.userId {
                    canUnlock = false
                }
            }

            guard !isAnyOffline else { continue }
            if metadata.directory,
               let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, metadata.serverUrl + "/" + metadata.fileName)) {
                isAnyOffline = directory.offline
            } else if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                isAnyOffline = localFile.offline
            } // else: file is not offline, continue
        }

        actions.append(.openInAction(selectedMetadatas: selectedMetadatas, viewController: self, completion: tapSelect))

        if !isAnyFolder, canUnlock, !NCGlobal.shared.capabilityFilesLockVersion.isEmpty {
            actions.append(.lockUnlockFiles(shouldLock: !isAnyLocked, metadatas: selectedMetadatas, completion: tapSelect))
        }

        if !selectedMediaMetadatas.isEmpty {
            actions.append(.saveMediaAction(selectedMediaMetadatas: selectedMediaMetadatas, completion: tapSelect))
        }
        actions.append(.setAvailableOfflineAction(selectedMetadatas: selectedMetadatas, isAnyOffline: isAnyOffline, viewController: self, completion: {
            self.reloadDataSource(withQueryDB: true)
            self.tapSelect()
        }))

        actions.append(.moveOrCopyAction(selectedMetadatas: selectedMetadatas, indexPath: selectIndexPath, completion: tapSelect))
        actions.append(.copyAction(selectOcId: selectOcId, completion: tapSelect))
        actions.append(.deleteAction(selectedMetadatas: selectedMetadatas, indexPath: selectIndexPath, viewController: self, completion: tapSelect))
        return actions
    }
}
