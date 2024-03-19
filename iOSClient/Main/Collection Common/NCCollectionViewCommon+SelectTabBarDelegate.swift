//
//  NCCollectionViewCommon+SelectTabBarDelegate.swift
//  Nextcloud
//
//  Created by Milen on 01.03.24.
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

import Foundation
import NextcloudKit

extension NCCollectionViewCommon: NCSelectableNavigationView, NCCollectionViewCommonSelectTabBarDelegate {
    func setNavigationRightItems(enableMenu: Bool = false) {
        guard let tabBarSelect = tabBarSelect as? NCCollectionViewCommonSelectTabBar,
              layoutKey != NCGlobal.shared.layoutViewTransfers else { return }

        var selectedMetadatas: [tableMetadata] = []
        var isAnyOffline = false
        var isAnyDirectory = false
        var isAllDirectory = true
        var isAnyLocked = false
        var canUnlock = true
        var canSetAsOffline = true
        let isTabBarHidden = self.tabBarController?.tabBar.isHidden ?? true
        let isTabBarSelectHidden = tabBarSelect.isHidden()

        for ocId in selectOcId {
            guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { continue }
            selectedMetadatas.append(metadata)

            if metadata.directory {
                isAnyDirectory = true
            } else {
                isAllDirectory = false
            }

            if !metadata.canSetAsAvailableOffline {
                canSetAsOffline = false
            }

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

        tabBarSelect.isAnyOffline = isAnyOffline
        tabBarSelect.canSetAsOffline = canSetAsOffline
        tabBarSelect.isAnyDirectory = isAnyDirectory
        tabBarSelect.isAllDirectory = isAllDirectory
        tabBarSelect.isAnyLocked = isAnyLocked
        tabBarSelect.canUnlock = canUnlock
        tabBarSelect.enableLock = !isAnyDirectory && canUnlock && !NCGlobal.shared.capabilityFilesLockVersion.isEmpty
        tabBarSelect.isSelectedEmpty = selectOcId.isEmpty
        tabBarSelect.selectedMetadatas = selectedMetadatas

        if isEditMode {
            tabBarSelect.show()
            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) { self.toggleSelect() }
            navigationItem.rightBarButtonItems = [select]
        } else {
            tabBarSelect.hide()
            if navigationItem.rightBarButtonItems == nil || enableMenu {
                let menuButton = UIBarButtonItem(image: .init(systemName: "ellipsis.circle"), menu: UIMenu(children: createMenuActions()))
                if layoutKey == NCGlobal.shared.layoutViewFiles {
                    let notification = UIBarButtonItem(image: .init(systemName: "bell"), style: .plain, action: tapNotification)
                    navigationItem.rightBarButtonItems = [menuButton, notification]
                } else {
                    navigationItem.rightBarButtonItems = [menuButton]
                }
            } else {
                navigationItem.rightBarButtonItems?.first?.menu = navigationItem.rightBarButtonItems?.first?.menu?.replacingChildren(createMenuActions())
            }
        }
        // fix, if the tabbar was hidden before the update, set hidden
        if isTabBarHidden, isTabBarSelectHidden {
            self.tabBarController?.tabBar.isHidden = true
        }
    }

    func onListSelected() {
        if layoutForView?.layout == NCGlobal.shared.layoutGrid {
            layoutForView?.layout = NCGlobal.shared.layoutList
            NCManageDatabase.shared.setLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl, layout: layoutForView?.layout)
            self.groupByField = "name"
            if self.dataSource.groupByField != self.groupByField {
                self.dataSource.changeGroupByField(self.groupByField)
            }

            self.collectionView.reloadData()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setCollectionViewLayout(self.listLayout, animated: true) {_ in self.isTransitioning = false }
        }
    }

    func onGridSelected() {
        if layoutForView?.layout == NCGlobal.shared.layoutList {
            layoutForView?.layout = NCGlobal.shared.layoutGrid
            NCManageDatabase.shared.setLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl, layout: layoutForView?.layout)
            if isSearchingMode {
                self.groupByField = "name"
            } else {
                self.groupByField = "classFile"
            }
            if self.dataSource.groupByField != self.groupByField {
                self.dataSource.changeGroupByField(self.groupByField)
            }

            self.collectionView.reloadData()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setCollectionViewLayout(self.gridLayout, animated: true) {_ in self.isTransitioning = false }
        }
    }

    func selectAll() {
        collectionViewSelectAll()
    }

    func delete(selectedMetadatas: [tableMetadata]) {
        let alertController = UIAlertController(
            title: NSLocalizedString("_confirm_delete_selected_", comment: ""),
            message: nil,
            preferredStyle: .alert)

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
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "onlyLocalCache": false, "error": error])
                }

                self.toggleSelect()
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
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "onlyLocalCache": true, "error": error])
                self.toggleSelect()
            }
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })
        self.viewController.present(alertController, animated: true, completion: nil)
    }

    func move(selectedMetadatas: [tableMetadata]) {
        NCActionCenter.shared.openSelectView(items: selectedMetadatas)
        self.toggleSelect()
    }

    func share(selectedMetadatas: [tableMetadata]) {
        NCActionCenter.shared.openActivityViewController(selectedMetadata: selectedMetadatas)
        self.toggleSelect()
    }

    func saveAsAvailableOffline(selectedMetadatas: [tableMetadata], isAnyOffline: Bool) {
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

        self.toggleSelect()
    }

    func createMenuActions() -> [UIMenuElement] {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl) else { return [] }

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""), image: .init(systemName: "checkmark.circle"), attributes: selectableDataSource.isEmpty ? .disabled : []) { _ in self.toggleSelect() }

        let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: .init(systemName: "list.bullet"), state: layoutForView.layout == NCGlobal.shared.layoutList ? .on : .off) { _ in
            self.onListSelected()
            self.setNavigationRightItems()
        }

        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: .init(systemName: "square.grid.2x2"), state: layoutForView.layout == NCGlobal.shared.layoutGrid ? .on : .off) { _ in
            self.onGridSelected()
            self.setNavigationRightItems()
        }

        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid])

        let ascending = layoutForView.ascending
        let ascendingChevronImage = UIImage(systemName: ascending ? "chevron.up" : "chevron.down")
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

        let personalFilesOnly = NCKeychain().getPersonalFilesOnly(account: appDelegate.account)
        let personalFilesOnlyAction = UIAction(title: NSLocalizedString("_personal_files_only_", comment: ""), image: UIImage(systemName: "folder.badge.person.crop"), state: personalFilesOnly ? .on : .off) { _ in
            NCKeychain().setPersonalFilesOnly(account: self.appDelegate.account, value: !personalFilesOnly)
            self.reloadDataSource()
        }

        let showDescriptionKeychain = NCKeychain().showDescription
        let showDescription = UIAction(title: NSLocalizedString("_show_description_", comment: ""), image: UIImage(systemName: "list.dash.header.rectangle"), attributes: richWorkspaceText == nil ? .disabled : [], state: showDescriptionKeychain && richWorkspaceText != nil ? .on : .off) { _ in
            NCKeychain().showDescription = !showDescriptionKeychain
            self.collectionView.reloadData()
            self.setNavigationRightItems()
        }
        showDescription.subtitle = richWorkspaceText == nil ? NSLocalizedString("_no_description_available_", comment: "") : ""

        if layoutKey == NCGlobal.shared.layoutViewRecent {
            return [select]
        } else {
            var additionalSubmenu = UIMenu()
            if layoutKey == NCGlobal.shared.layoutViewFiles {
                additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop, personalFilesOnlyAction, showDescription])
            } else {
                additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop, showDescription])
            }
            return [select, viewStyleSubmenu, sortSubmenu, additionalSubmenu]
        }
    }
}
