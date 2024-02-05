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

public protocol NCSelectableViewTabBar {}

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
    var serverUrl: String { get }
    var tabBarSelect: NCSelectableViewTabBar? { get set }

    func reloadDataSource(withQueryDB: Bool)
    func setNavigationItems()
    func setNavigationRightItems()

    func toggleSelect()
    func onListSelected()
    func onGridSelected()
}

extension NCSelectableNavigationView {
//    func selectAll() {
//        self.collectionViewSelectAll()
//    }
//
//    func delete(selectedMetadatas: [tableMetadata]) {
//        let alertController = UIAlertController(
//            title: NSLocalizedString("_confirm_delete_selected_", comment: ""),
//            message: nil,
//            preferredStyle: .actionSheet)
//
//        let canDeleteServer = selectedMetadatas.allSatisfy { !$0.lock }
//
//        if canDeleteServer {
//            let copyMetadatas = selectedMetadatas
//
//            alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .destructive) { _ in
//                Task {
//                    var error = NKError()
//                    var ocId: [String] = []
//                    for metadata in copyMetadatas where error == .success {
//                        error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false)
//                        if error == .success {
//                            ocId.append(metadata.ocId)
//                        }
//                    }
//                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "indexPath": self.selectIndexPath, "onlyLocalCache": false, "error": error])
//                    self.toggleSelect()
//                }
//            })
//        }
//
//        alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (_: UIAlertAction) in
//            let copyMetadatas = selectedMetadatas
//
//            Task {
//                var error = NKError()
//                var ocId: [String] = []
//                for metadata in copyMetadatas where error == .success {
//                    error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: true)
//                    if error == .success {
//                        ocId.append(metadata.ocId)
//                    }
//                }
//                if error != .success {
//                    NCContentPresenter().showError(error: error)
//                }
//                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "indexPath": self.selectIndexPath, "onlyLocalCache": true, "error": error])
//                self.toggleSelect()
//            }
//        })
//
//        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })
//        self.viewController.present(alertController, animated: true, completion: nil)
//    }
//
//    func move(selectedMetadatas: [tableMetadata]) {
//        NCActionCenter.shared.openSelectView(items: selectedMetadatas, indexPath: self.selectIndexPath)
//    }
//
//    func share(selectedMetadatas: [tableMetadata]) {
//        NCActionCenter.shared.openActivityViewController(selectedMetadata: selectedMetadatas)
//    }
//
//    func download(selectedMetadatas: [tableMetadata], isAnyOffline: Bool) {
//        if !isAnyOffline, selectedMetadatas.count > 3 {
//            let alert = UIAlertController(
//                title: NSLocalizedString("_set_available_offline_", comment: ""),
//                message: NSLocalizedString("_select_offline_warning_", comment: ""),
//                preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: NSLocalizedString("_continue_", comment: ""), style: .default, handler: { _ in
//                selectedMetadatas.forEach { NCActionCenter.shared.setMetadataAvalableOffline($0, isOffline: isAnyOffline) }
//                self.toggleSelect()
//            }))
//            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
//            self.viewController.present(alert, animated: true)
//        } else {
//            selectedMetadatas.forEach { NCActionCenter.shared.setMetadataAvalableOffline($0, isOffline: isAnyOffline) }
//            self.toggleSelect()
//        }
//    }
//
//    func lock(selectedMetadatas: [tableMetadata], isAnyLocked: Bool) {
//        for metadata in selectedMetadatas where metadata.lock == isAnyLocked {
//            NCNetworking.shared.lockUnlockFile(metadata, shoulLock: !isAnyLocked)
//        }
//    }

    func setNavigationItems() {
        setNavigationRightItems()
    }

    private func createTrashMenuActions() -> [UIMenuElement] {
        guard let trashVC = (viewController as? NCTrash) else { return [] }

        let recover = UIAction(title: NSLocalizedString("_recover_", comment: ""), image: .init(systemName: "trash.slash"), attributes: selectOcId.isEmpty ? [.disabled] : []) { _ in
            self.selectOcId.forEach(trashVC.restoreItem)
            self.toggleSelect()
        }

        let delete = UIAction(title: NSLocalizedString("_delete_", comment: ""), image: .init(systemName: "trash"), attributes: selectOcId.isEmpty ? [.disabled, .destructive] : [.destructive]) { _ in
            let alert = UIAlertController(title: NSLocalizedString("_trash_delete_selected_", comment: ""), message: "", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_delete_", comment: ""), style: .destructive, handler: { _ in
                self.selectOcId.forEach(trashVC.deleteItem)
                self.toggleSelect()
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in }))
            trashVC.present(alert, animated: true, completion: nil)
        }

        return [recover, delete]
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

        let lock = UIAction(title: NSLocalizedString(isAnyLocked ? "_unlock_" : "_lock_", comment: ""), image: .init(systemName: isAnyLocked ? "lock.open" : "lock"), attributes: enableLock && !selectOcId.isEmpty ? [] : [.disabled]) { _ in
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

        return [download, lock, share, move, delete]
    }

    func saveLayout(_ layoutForView: NCDBLayoutForView) {
        NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)

        setNavigationRightItems()
    }

    func toggleSelect() {
        DispatchQueue.main.async {
            self.isEditMode = !self.isEditMode
            self.selectOcId.removeAll()
            self.selectIndexPath.removeAll()
            self.setNavigationItems()
            self.collectionView.reloadData()
        }
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
//    var tabBarSelect: NCCollectionViewCommonSelectTabBar {
////        NCCollectionViewCommonSelectTabBar(tabBarController: tabBarController, height: 80, delegate: self)
////    }

    var viewController: UIViewController {
        self
    }
}

extension NCSelectableNavigationView where Self: NCCollectionViewCommon, Self: NCCollectionViewCommonSelectTabBarDelegate {
//    var tabBarSelect: NCCollectionViewCommonSelectTabBar {
////        NCCollectionViewCommonSelectTabBar(tabBarController: tabBarController, height: 80, delegate: self)
////    }

    var viewController: UIViewController {
        self
    }

    func selectAll() {
        self.collectionViewSelectAll()
    }

    func delete(selectedMetadatas: [tableMetadata]) {
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
                    await NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "indexPath": self.selectIndexPath, "onlyLocalCache": false, "error": error])
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
                await NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "indexPath": self.selectIndexPath, "onlyLocalCache": true, "error": error])
                self.toggleSelect()
            }
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })
        self.viewController.present(alertController, animated: true, completion: nil)
    }

    func move(selectedMetadatas: [tableMetadata]) {
        NCActionCenter.shared.openSelectView(items: selectedMetadatas, indexPath: self.selectIndexPath)
    }

    func share(selectedMetadatas: [tableMetadata]) {
        NCActionCenter.shared.openActivityViewController(selectedMetadata: selectedMetadatas)
    }

    func download(selectedMetadatas: [tableMetadata], isAnyOffline: Bool) {
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

    func lock(selectedMetadatas: [tableMetadata], isAnyLocked: Bool) {
        for metadata in selectedMetadatas where metadata.lock == isAnyLocked {
            NCNetworking.shared.lockUnlockFile(metadata, shoulLock: !isAnyLocked)
        }
    }
}
