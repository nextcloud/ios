// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import Foundation
import NextcloudKit
import LucidBanner

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
                Task {
                    await self.setEditMode(false)
                    var metadatasPlain: [tableMetadata] = []
                    var metadatasE2EE: [tableMetadata] = []

                    for metadata in metadatas {
                        if metadata.isDirectoryE2EE {
                            metadatasE2EE.append(metadata)
                        } else {
                            metadatasPlain.append(metadata)
                        }
                    }

                    if !metadatasPlain.isEmpty {
                        let error = await self.networking.setStatusWaitDelete(metadatas: metadatasPlain)
                        if error != .success {
                            await showErrorBanner(controller: self.controller, error: error)
                        }
                    }

                    if !metadatasE2EE.isEmpty {
                        if self.networking.isOffline {
                            await showErrorBanner(controller: self.controller,
                                                  text: "_offline_not_allowed_",
                                                  errorCode: self.global.errorOfflineNotAllowed)
                        } else {
                            var cancelOnTap = false
                            var num: Float = 0
                            let total = Float(metadatasE2EE.count)

                            let token = showHudBanner(
                                scene: self.scene,
                                title: NSLocalizedString("_delete_in_progress_", comment: ""),
                                stage: .button) {
                                    cancelOnTap = true
                                }
                            for metadata in metadatasE2EE {
                                let error = await NCNetworkingE2EEDelete().delete(metadata: metadata)
                                num += 1
                                LucidBanner.shared.update(
                                    payload: LucidBannerPayload.Update(progress: Double(num) / Double(total)),
                                    for: token
                                )
                                if cancelOnTap || error != .success {
                                    break
                                }
                            }
                            LucidBanner.shared.dismiss()
                        }
                    }
                    await self.reloadDataSource()
                }
            })
        }

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (_: UIAlertAction) in
            let copyMetadatas = metadatas

            Task {
                for metadata in copyMetadatas {
                    var token: Int?
                    if metadata.isDirectory {
                        token = showHudBanner(
                            scene: self.scene,
                            title: NSLocalizedString("_delete_in_progress_", comment: "")
                        )
                    }

                    await self.networking.deleteCache(metadata, progress: { progress in
                        Task {
                            if let token {
                                LucidBanner.shared.update(
                                    payload: LucidBannerPayload.Update(progress: progress),
                                    for: token
                                )
                            }
                        }

                    })
                    LucidBanner.shared.dismiss()
                }
                await self.setEditMode(false)
            }
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })
        self.present(alertController, animated: true, completion: nil)
    }

    func move() {
        Task {
            let metadatas = getSelectedMetadatas()
            await setEditMode(false)

            NCSelectOpen.shared.openView(items: metadatas, controller: self.controller)
        }

    }

    func share() {
        Task {
            let metadatas = getSelectedMetadatas()
            await setEditMode(false)
            await NCCreate().createActivityViewController(
                selectedMetadata: metadatas,
                controller: self.controller,
                sender: nil)
        }
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
                        await NCNetworking.shared.setMetadataAvalableOffline(metadata, isOffline: isAnyOffline)
                    }
                    await  self.setEditMode(false)
                }

            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
            self.present(alert, animated: true)
        } else {
            Task {
                for metadata in metadatas {
                    await NCNetworking.shared.setMetadataAvalableOffline(metadata, isOffline: isAnyOffline)
                }
                await setEditMode(false)
            }
        }
    }

    func lock(isAnyLocked: Bool) {
        Task {
            let metadatas = getSelectedMetadatas()
            for metadata in metadatas where metadata.lock == isAnyLocked {
                let error = await self.networking.lockUnlockFile(metadata, shouldLock: !isAnyLocked)
                if error != .success {
                    await showErrorBanner(controller: self.controller, error: error)
                }
            }
            await setEditMode(false)
        }
    }

    func getSelectedMetadatas() -> [tableMetadata] {
        var selectedMetadatas: [tableMetadata] = []
        for ocId in fileSelect {
            guard let metadata = database.getMetadataFromOcId(ocId) else { continue }
            selectedMetadatas.append(metadata)
        }
        return selectedMetadatas
    }

    @MainActor
    func setEditMode(_ editMode: Bool) async {
        isEditMode = editMode
        fileSelect.removeAll()

        navigationItem.hidesBackButton = editMode
        navigationController?.interactivePopGestureRecognizer?.isEnabled = !editMode
        searchController(enabled: !editMode)

        // (+)
        mainNavigationController?.menuPlus?.hiddenPlusButton(editMode)

        if editMode {
            navigationItem.leftBarButtonItems = nil
        } else {
            await (self.navigationController as? NCMainNavigationController)?.setNavigationLeftItems()
        }
        await (self.navigationController as? NCMainNavigationController)?.setNavigationRightItems()

        self.collectionView.reloadData()
    }
}
