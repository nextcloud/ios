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
    var viewController: UIViewController { get }
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
    var serverUrl: String { get }

    func reloadDataSource(withQueryDB: Bool)
    func setNavigationItems()

//    func tapSelectMenu()
    func toggleSelect()
    func onListSelected()
    func onGridSelected()
}

extension NCSelectableNavigationView {
    func setNavigationItems() {
        setNavigationRightItems()
    }

    func setNavigationRightItems() {
        if isEditMode {
            let select = UIBarButtonItem(title: NSLocalizedString("_done_", comment: ""), style: .done) { self.toggleSelect() }

            let menu = UIMenu(children: createSelectMenuActions())
            let menuButton = UIBarButtonItem(image: .init(systemName: "ellipsis.circle"), menu: menu)

            navigationItem.rightBarButtonItems = [select, menuButton]
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
        }
    }

    private func createSelectMenuActions() -> [UIMenuElement] {
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

        let selectAll = UIAction(title: NSLocalizedString("_select_all_", comment: ""), image: .init(systemName: "checkmark")) { _ in self.collectionViewSelectAll() }

        let download = UIAction(title: NSLocalizedString("_download_", comment: ""), image: .init(systemName: "icloud.and.arrow.down"), attributes: selectOcId.isEmpty ? .disabled : []) { _ in
            if !isAnyOffline, selectedMetadatas.count > 3 {
                let alert = UIAlertController(
                    title: NSLocalizedString("_set_available_offline_", comment: ""),
                    message: NSLocalizedString("_select_offline_warning_", comment: ""),
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("_continue_", comment: ""), style: .default, handler: { _ in
                    selectedMetadatas.forEach { NCActionCenter.shared.setMetadataAvalableOffline($0, isOffline: isAnyOffline) }
                    self.toggleSelect()
                }))
                alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
                self.viewController.present(alert, animated: true)
            } else {
                selectedMetadatas.forEach { NCActionCenter.shared.setMetadataAvalableOffline($0, isOffline: isAnyOffline) }
                self.toggleSelect()
            }
        }

        let share = UIAction(title: NSLocalizedString("_share_title_", comment: ""), image: .init(systemName: "square.and.arrow.up"), attributes: selectOcId.isEmpty ? [.disabled] : []) { _ in
            NCActionCenter.shared.openActivityViewController(selectedMetadata: selectedMetadatas)
        }

        let enableLock = !isAnyFolder && canUnlock && !NCGlobal.shared.capabilityFilesLockVersion.isEmpty

        let lock = UIAction(title: NSLocalizedString(isAnyLocked ? "_unlock_file_" : "_lock_file_", comment: ""), image: .init(systemName: isAnyLocked ? "lock.open" : "lock"), attributes: enableLock && !selectOcId.isEmpty ? [] : [.disabled]) { _ in
            for metadata in selectedMetadatas where metadata.lock == isAnyLocked {
                NCNetworking.shared.lockUnlockFile(metadata, shoulLock: !isAnyLocked)
            }

            self.toggleSelect()
        }

        lock.subtitle = enableLock ? nil : NSLocalizedString("_lock_no_permissions_selected_", comment: "")

        let move = UIAction(title: NSLocalizedString("_move_or_copy_", comment: ""), image: .init(systemName: "arrow.up.and.down.and.arrow.left.and.right"), attributes: selectOcId.isEmpty ? [.disabled] : []) { _ in
            NCActionCenter.shared.openSelectView(items: selectedMetadatas, indexPath: self.selectIndexPath)
        }

        let delete = UIAction(title: NSLocalizedString("_delete_", comment: ""), image: .init(systemName: "trash"), attributes: selectOcId.isEmpty ? [.disabled, .destructive] : .destructive) { _ in
            let alertController = UIAlertController(
                title: NSLocalizedString("_confirm_delete_selected_", comment: ""),
                message: nil,
                preferredStyle: .actionSheet)

            let canDeleteServer = selectedMetadatas.allSatisfy { !$0.lock }

            if canDeleteServer {
                let copyMetadatas = selectedMetadatas

                alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .destructive) { _ in
                    Task {
                        var error = NKError()
                        var ocId: [String] = []
                        for metadata in copyMetadatas where error == .success {
                            error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false)
                            if error == .success {
                                ocId.append(metadata.ocId)
                            }
                        }
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "indexPath": self.selectIndexPath, "onlyLocalCache": false, "error": error])
                        self.toggleSelect()
                    }
                })
            }

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (_: UIAlertAction) in
                let copyMetadatas = selectedMetadatas

                Task {
                    var error = NKError()
                    var ocId: [String] = []
                    for metadata in copyMetadatas where error == .success {
                        error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: true)
                        if error == .success {
                            ocId.append(metadata.ocId)
                        }
                    }
                    if error != .success {
                        NCContentPresenter().showError(error: error)
                    }
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "indexPath": self.selectIndexPath, "onlyLocalCache": true, "error": error])
                    self.toggleSelect()
                }
            })

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })
            self.viewController.present(alertController, animated: true, completion: nil)
        }

//        if layoutKey == NCGlobal.shared.layoutViewRecent {
//            return [select]
//        } else {
            return [selectAll, download, lock, share, move, delete]
//        }
    }

    private func createMenuActions() -> [UIMenuElement] {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl) else { return [] }

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""), image: .init(systemName: "checkmark.circle")) { _ in self.toggleSelect() }

        let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: .init(systemName: "list.bullet"), state: layoutForView.layout == NCGlobal.shared.layoutList ? .on : .off) { _ in
            self.onListSelected()
            self.setNavigationRightItems()
        }

        let grid = UIAction(title: NSLocalizedString("_grid_", comment: ""), image: .init(systemName: "square.grid.2x2"), state: layoutForView.layout == NCGlobal.shared.layoutGrid ? .on : .off) { _ in
            self.onGridSelected()
            self.setNavigationRightItems()
        }

        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid])

        let ascending = layoutForView.ascending
        let ascendingChevronImage = UIImage(systemName: ascending ? "chevron.down" : "chevron.up")
        let isName = layoutForView.sort == "fileName"
        let isDate = layoutForView.sort == "date"
        let isSize = layoutForView.sort == "size"

        let byName = UIAction(title: NSLocalizedString("_name_", comment: ""), image: isName ? ascendingChevronImage : nil, state: isName ? .on : .off) { _ in
            if isName { // repeated press
                layoutForView.ascending = !layoutForView.ascending
            }

            layoutForView.sort = "fileName"
            self.saveLayout(layoutForView)
        }

        let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""), image: isDate ? ascendingChevronImage : nil, state: isDate ? .on : .off) { _ in
            if isDate { // repeated press
                layoutForView.ascending = !layoutForView.ascending
            }

            layoutForView.sort = "date"
            self.saveLayout(layoutForView)
        }

        let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""), image: isSize ? ascendingChevronImage : nil, state: isSize ? .on : .off) { _ in
            if isSize { // repeated press
                layoutForView.ascending = !layoutForView.ascending
            }

            layoutForView.sort = "size"
            self.saveLayout(layoutForView)
        }

        let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""), options: .displayInline, children: [byName, byNewest, byLargest])

        let foldersOnTop = UIAction(title: NSLocalizedString("_directory_on_top_no_", comment: ""), image: UIImage(systemName: "folder"), state: layoutForView.directoryOnTop ? .on : .off) { _ in
            layoutForView.directoryOnTop = !layoutForView.directoryOnTop
            self.saveLayout(layoutForView)
        }

        let foldersSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop])

        if layoutKey == NCGlobal.shared.layoutViewRecent {
            return [select]
        } else {
            return [select, viewStyleSubmenu, sortSubmenu, foldersSubmenu]
        }
    }

    private func saveLayout(_ layoutForView: NCDBLayoutForView) {
        NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)

        setNavigationRightItems()
    }

    func toggleSelect() {
        isEditMode = !isEditMode
        selectOcId.removeAll()
        selectIndexPath.removeAll()
        self.setNavigationItems()
        self.collectionView.reloadData()
    }

    func collectionViewSelectAll() {
        selectOcId = selectableDataSource.compactMap({ $0.primaryKeyValue })
        collectionView.reloadData()
        self.setNavigationRightItems()
    }

    func tapNotification() {
        if let viewController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? NCNotification {
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
}

extension NCSelectableNavigationView where Self: UIViewController {
    var selectActions: [NCMenuAction] {
        var actions = [NCMenuAction]()

        actions.append(.cancelAction {
            self.toggleSelect()
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

        actions.append(.openInAction(selectedMetadatas: selectedMetadatas, viewController: self, completion: toggleSelect))

        if !isAnyFolder, canUnlock, !NCGlobal.shared.capabilityFilesLockVersion.isEmpty {
            actions.append(.lockUnlockFiles(shouldLock: !isAnyLocked, metadatas: selectedMetadatas, completion: toggleSelect))
        }

        if !selectedMediaMetadatas.isEmpty {
            actions.append(.saveMediaAction(selectedMediaMetadatas: selectedMediaMetadatas, completion: toggleSelect))
        }
        actions.append(.setAvailableOfflineAction(selectedMetadatas: selectedMetadatas, isAnyOffline: isAnyOffline, viewController: self, completion: {
            self.reloadDataSource(withQueryDB: true)
            self.toggleSelect()
        }))

        actions.append(.moveOrCopyAction(selectedMetadatas: selectedMetadatas, indexPath: selectIndexPath, completion: toggleSelect))
        actions.append(.copyAction(selectOcId: selectOcId, completion: toggleSelect))
        actions.append(.deleteAction(selectedMetadatas: selectedMetadatas, indexPath: selectIndexPath, viewController: self, completion: toggleSelect))
        return actions
    }
}
