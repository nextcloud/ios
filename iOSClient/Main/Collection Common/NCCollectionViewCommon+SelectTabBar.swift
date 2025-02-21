//
//  NCCollectionViewCommon+SelectTabBar.swift
//  Nextcloud
//
//  Created by Milen on 01.03.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//  Copyright © 2024 STRATO GmbH
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
import Foundation
import NextcloudKit

extension NCCollectionViewCommon: HiDriveCollectionViewCommonSelectToolbarDelegate {
    func selectAll() {
        if !fileSelect.isEmpty, self.dataSource.getMetadatas().count == fileSelect.count {
            fileSelect = []
        } else {
            fileSelect = self.dataSource.getMetadatas().compactMap({ $0.ocId })
        }
        tabBarSelect?.update(fileSelect: fileSelect, metadatas: getSelectedMetadatas(), userId: session.userId)
        self.collectionView.reloadData()
    }

    func delete() {
        var alertStyle = UIAlertController.Style.actionSheet
        if UIDevice.current.userInterfaceIdiom == .pad { alertStyle = .alert }
        let alertController = UIAlertController(title: NSLocalizedString("_confirm_delete_selected_", comment: ""), message: nil, preferredStyle: alertStyle)
        alertController.view.backgroundColor = NCBrandColor.shared.appBackgroundColor
        let metadatas = getSelectedMetadatas()
        let canDeleteServer = metadatas.allSatisfy { !$0.lock }

        if canDeleteServer {
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .destructive) { _ in
                NCNetworking.shared.deleteMetadatas(metadatas, sceneIdentifier: self.controller?.sceneIdentifier)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
                self.setEditMode(false)
            })
        }

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (_: UIAlertAction) in
            let copyMetadatas = metadatas

            Task {
                var error = NKError()
                var ocId: [String] = []
                for metadata in copyMetadatas where error == .success {
                    error = await NCNetworking.shared.deleteCache(metadata, sceneIdentifier: self.controller?.sceneIdentifier)
                    if error == .success {
                        ocId.append(metadata.ocId)
                    }
                }
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "error": error])
            }
            self.setEditMode(false)
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })
        self.present(alertController, animated: true, completion: nil)
    }

    func move() {
        let metadatas = getSelectedMetadatas()

        NCActionCenter.shared.openSelectView(items: metadatas, controller: self.controller)
        setEditMode(false)
    }

    func share() {
        let metadatas = getSelectedMetadatas()
        NCActionCenter.shared.openActivityViewController(selectedMetadata: metadatas, controller: self.controller)
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

    func getSelectedMetadatas() -> [tableMetadata] {
        var selectedMetadatas: [tableMetadata] = []
        for ocId in fileSelect {
            guard let metadata = database.getMetadataFromOcId(ocId) else { continue }
            selectedMetadatas.append(metadata)
        }
        return selectedMetadatas
    }

    func setEditMode(_ editMode: Bool) {
        isEditMode = editMode
        fileSelect.removeAll()

        if editMode {
            navigationItem.leftBarButtonItems = nil
        } else {
            (self.navigationController as? HiDriveMainNavigationController)?.setNavigationLeftItems()
        }
        (self.navigationController as? HiDriveMainNavigationController)?.setNavigationRightItems()

        navigationController?.interactivePopGestureRecognizer?.isEnabled = !editMode
        navigationItem.hidesBackButton = editMode
        searchController(enabled: !editMode)
        self.collectionView.reloadData()
    }
    
    func toolbarWillAppear() {
        self.tabBarController?.tabBar.isHidden = true
    }
    
    func toolbarWillDisappear() {
        self.tabBarController?.tabBar.isHidden = false
    }
}
