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

extension NCCollectionViewCommon: NCCollectionViewCommonSelectTabBarDelegate {
    func setNavigationRightItems(enableMenu: Bool = false) {
        guard layoutKey != NCGlobal.shared.layoutViewTransfers else { return }
        let isTabBarHidden = self.tabBarController?.tabBar.isHidden ?? true
        let isTabBarSelectHidden = tabBarSelect.isHidden()

        if isEditMode {
            tabBarSelect.update(selectOcId: selectOcId, metadatas: getSelectedMetadatas(), userId: appDelegate.userId)
            tabBarSelect.show()
            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                self.setEditMode(false)
            }
            navigationItem.rightBarButtonItems = [select]
        } else {
            tabBarSelect.hide()
            if navigationItem.rightBarButtonItems == nil || enableMenu {
                let menuButton = UIBarButtonItem(image: .init(systemName: "ellipsis.circle"), menu: UIMenu(children: createMenuActions()))
                if layoutKey == NCGlobal.shared.layoutViewFiles {
                    let notification = UIBarButtonItem(image: .init(systemName: "bell"), style: .plain) {
                        if let viewController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? NCNotification {
                            self.navigationController?.pushViewController(viewController, animated: true)
                        }
                    }
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
        if !selectOcId.isEmpty, dataSource.getMetadataSourceForAllSections().count == selectOcId.count {
            selectOcId = []
        } else {
            selectOcId = dataSource.getMetadataSourceForAllSections().compactMap({ $0.ocId })
        }
        tabBarSelect.update(selectOcId: selectOcId, metadatas: getSelectedMetadatas(), userId: appDelegate.userId)
        collectionView.reloadData()
    }

    func delete() {
        let alertController = UIAlertController(
            title: NSLocalizedString("_confirm_delete_selected_", comment: ""),
            message: nil,
            preferredStyle: .alert)
        let metadatas = getSelectedMetadatas()
        let canDeleteServer = metadatas.allSatisfy { !$0.lock }

        if canDeleteServer {
            let copyMetadatas = metadatas

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
                self.setEditMode(false)
            })
        }

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (_: UIAlertAction) in
            let copyMetadatas = metadatas

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
                self.setEditMode(false)
            }
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })
        self.present(alertController, animated: true, completion: nil)
    }

    func move() {
        let metadatas = getSelectedMetadatas()
        NCActionCenter.shared.openSelectView(items: metadatas)
        setEditMode(false)
    }

    func share() {
        let metadatas = getSelectedMetadatas()
        NCActionCenter.shared.openActivityViewController(selectedMetadata: metadatas)
        setEditMode(false)
    }

    func saveAsAvailableOffline(isAnyOffline: Bool) {
        let metadatas = getSelectedMetadatas()
        if !isAnyOffline, metadatas.count > 3 {
            let alert = UIAlertController(
                title: NSLocalizedString("_set_available_offline_", comment: ""),
                message: NSLocalizedString("_select_offline_warning_", comment: ""),
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_continue_", comment: ""), style: .default, handler: { _ in
                metadatas.forEach { NCActionCenter.shared.setMetadataAvalableOffline($0, isOffline: isAnyOffline) }
                self.setEditMode(false)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
            self.present(alert, animated: true)
        } else {
            metadatas.forEach { NCActionCenter.shared.setMetadataAvalableOffline($0, isOffline: isAnyOffline) }
            setEditMode(false)
        }
    }

    func lock(isAnyLocked: Bool) {
        let metadatas = getSelectedMetadatas()
        for metadata in metadatas where metadata.lock == isAnyLocked {
            NCNetworking.shared.lockUnlockFile(metadata, shoulLock: !isAnyLocked)
        }
        setEditMode(false)
    }

    func createMenuActions() -> [UIMenuElement] {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl) else { return [] }

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""), image: .init(systemName: "checkmark.circle"), attributes: self.dataSource.getMetadataSourceForAllSections().isEmpty ? .disabled : []) { _ in
            self.setEditMode(true)
        }

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

    func saveLayout(_ layoutForView: NCDBLayoutForView) {
        NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
        setNavigationRightItems(enableMenu: false)
    }

    func getSelectedMetadatas() -> [tableMetadata] {
        var selectedMetadatas: [tableMetadata] = []
        for ocId in selectOcId {
            guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { continue }
            selectedMetadatas.append(metadata)
        }
        return selectedMetadatas
    }
}
