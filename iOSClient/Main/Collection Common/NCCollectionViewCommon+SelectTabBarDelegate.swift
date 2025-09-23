// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import Foundation
import NextcloudKit

extension NCCollectionViewCommon: NCCollectionViewCommonSelectTabBarDelegate {
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
        let metadatas = getSelectedMetadatas()
        let canDeleteServer = metadatas.allSatisfy { !$0.lock }

        if canDeleteServer {
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .destructive) { _ in
                self.setEditMode(false)
                Task {
                    await self.networking.setStatusWaitDelete(metadatas: metadatas, sceneIdentifier: self.controller?.sceneIdentifier)
                    await self.reloadDataSource()
                }
            })
        }

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (_: UIAlertAction) in
            let copyMetadatas = metadatas

            Task {
                var error = NKError()
                for metadata in copyMetadatas where error == .success {
                    error = await self.networking.deleteCache(metadata, sceneIdentifier: self.controller?.sceneIdentifier)
                }
            }
            self.setEditMode(false)
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })
        self.present(alertController, animated: true, completion: nil)
    }

    func move() {
        let metadatas = getSelectedMetadatas()

        NCDownloadAction.shared.openSelectView(items: metadatas, controller: self.controller)
        setEditMode(false)
    }

    func share() {
        let metadatas = getSelectedMetadatas()
        NCDownloadAction.shared.openActivityViewController(selectedMetadata: metadatas, controller: self.controller, sender: nil)
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
                Task {
                    for metadata in metadatas {
                        await NCDownloadAction.shared.setMetadataAvalableOffline(metadata, isOffline: isAnyOffline)
                    }
                }
                self.setEditMode(false)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
            self.present(alert, animated: true)
        } else {
            Task {
                for metadata in metadatas {
                    await NCDownloadAction.shared.setMetadataAvalableOffline(metadata, isOffline: isAnyOffline)
                }
            }
            setEditMode(false)
        }
    }

    func lock(isAnyLocked: Bool) {
        let metadatas = getSelectedMetadatas()
        for metadata in metadatas where metadata.lock == isAnyLocked {
            self.networking.lockUnlockFile(metadata, shoulLock: !isAnyLocked)
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
        Task {
            isEditMode = editMode
            fileSelect.removeAll()

            navigationItem.hidesBackButton = editMode
            navigationController?.interactivePopGestureRecognizer?.isEnabled = !editMode
            searchController(enabled: !editMode)
            mainNavigationController?.hiddenPlusButton(editMode)

            if editMode {
                navigationItem.leftBarButtonItems = nil
            } else {
                await (self.navigationController as? NCMainNavigationController)?.setNavigationLeftItems()
            }
            await (self.navigationController as? NCMainNavigationController)?.setNavigationRightItems()

            self.collectionView.reloadData()
        }
    }
}
