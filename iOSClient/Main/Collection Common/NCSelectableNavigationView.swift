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
    var titleCurrentFolder: String { get }
    var navigationItem: UINavigationItem { get }

    var selectActions: [NCMenuAction] { get }

    func reloadDataSource(forced: Bool)
    func setNavigationItem()

    func tapSelectMenu()
    func tapSelect()
}

extension NCSelectableNavigationView {

    func setNavigationItem() {
        setNavigationHeader()
    }

    func setNavigationHeader() {
        if isEditMode {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "navigationMore"), style: .plain, action: tapSelectMenu)
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .plain, action: tapSelect)
            navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(selectableDataSource.count)"
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_select_", comment: ""), style: UIBarButtonItem.Style.plain, action: tapSelect)
            navigationItem.leftBarButtonItem = nil
            navigationItem.title = titleCurrentFolder
        }
    }

    func tapSelect() {
        isEditMode = !isEditMode
        selectOcId.removeAll()
        self.setNavigationItem()
        self.collectionView.reloadData()
    }

    func collectionViewSelectAll() {
        selectOcId = selectableDataSource.compactMap({ $0.primaryKeyValue })
        navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(selectableDataSource.count)"
        collectionView.reloadData()
    }
}

extension NCSelectableNavigationView where Self: UIViewController {
    func tapSelectMenu() {
        presentMenu(with: selectActions)
    }

    var selectActions: [NCMenuAction] {
        var actions = [NCMenuAction]()
        if selectOcId.count != selectableDataSource.count {
            actions.append(.selectAllAction(action: collectionViewSelectAll))
        }

        guard !selectOcId.isEmpty else { return actions }
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

        if !isAnyFolder, canUnlock, NCManageDatabase.shared.getCapabilitiesServerInt(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesFilesLockVersion) >= 1 {
            actions.append(.lockUnlockFiles(shouldLock: !isAnyLocked, metadatas: selectedMetadatas, completion: tapSelect))
        }

        if !selectedMediaMetadatas.isEmpty {
            actions.append(.saveMediaAction(selectedMediaMetadatas: selectedMediaMetadatas, completion: tapSelect))
        }
        actions.append(.setAvailableOfflineAction(selectedMetadatas: selectedMetadatas, isAnyOffline: isAnyOffline, viewController: self, completion: {
            self.reloadDataSource(forced: true)
            self.tapSelect()
        }))

        actions.append(.moveOrCopyAction(selectedMetadatas: selectedMetadatas, completion: tapSelect))
        actions.append(.copyAction(selectOcId: selectOcId, hudView: self.view, completion: tapSelect))
        actions.append(.deleteAction(selectedMetadatas: selectedMetadatas, viewController: self, completion: tapSelect))
        return actions
    }
}
