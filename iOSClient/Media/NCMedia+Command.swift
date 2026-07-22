// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import SwiftUI

extension NCMedia {
    func setEditMode(_ editMode: Bool) {
        if dataSource.compactMetadatas.isEmpty {
            isEditMode = false
        } else {
            isEditMode = editMode
        }

        fileSelect.removeAll()
        tabBarSelect.selectCount = fileSelect.count

        if let visibleCells = collectionView?.indexPathsForVisibleItems.compactMap({ collectionView?.cellForItem(at: $0) }) {
            for case let cell as NCMediaCell in visibleCells {
                cell.selected(false, color: NCBrandColor.shared.getElement(account: session.account))
            }
        }

        self.collectionView.reloadData()

        Task {
            await (self.navigationController as? NCMainNavigationController)?.setNavigationLeftItems()
            await (self.navigationController as? NCMainNavigationController)?.setNavigationRightItems()
        }
    }

    func setTitleDate() {
        if let layoutAttributes = collectionView.collectionViewLayout.layoutAttributesForElements(in: collectionView.bounds) {
            let sortedAttributes = layoutAttributes.sorted { $0.frame.minY < $1.frame.minY || ($0.frame.minY == $1.frame.minY && $0.frame.minX < $1.frame.minX) }

            if let firstAttribute = sortedAttributes.first, let metadata = dataSource.getCompactMetadata(indexPath: firstAttribute.indexPath) {
                buttonDate.setTitle(utility.getTitleFromDate(metadata.date), for: .normal)
                return
            }
        }

        buttonDate.setTitle("", for: .normal)
    }

    func setElements() {
        let highTextTitle = buttonDate.frame.height
        let isOver =
            collectionView.contentOffset.y + highTextTitle <= -view.safeAreaInsets.top &&
            collectionView.contentOffset.y != -view.safeAreaInsets.top

        let shouldHideGradient = isOver || dataSource.compactMetadatas.isEmpty
        let foregroundColor: UIColor = shouldHideGradient ? NCBrandColor.shared.textColor : .white
        var configuration = buttonDate.configuration
        configuration?.baseForegroundColor = foregroundColor
        buttonDate.configuration = configuration
        activityIndicator.color = foregroundColor

        if #unavailable(iOS 26.0) {
            (navigationController as? NCMediaNavigationController)?
                .updateRightBarButtonsTint(to: foregroundColor)
        }

        if !shouldHideGradient {
            gradientView.isHidden = false
        }

        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.gradientView.alpha = shouldHideGradient ? 0 : 1
            },
            completion: { _ in
                self.gradientView.isHidden = shouldHideGradient
            }
        )

        setTitleDate()
    }
}

extension NCMedia: NCMediaSelectTabBarDelegate {
    func move() {
        Task {
            let ocIds = self.fileSelect.map { $0 }
            let metadatas = await database.getMetadatasFromOcIdsAsync(ocIds)

            setEditMode(false)

            NCSelectOpen.shared.openView(items: metadatas, controller: self.controller)
        }
    }

    func share() {
        Task {
            let ocIds = self.fileSelect.map { $0 }
            let metadatas = await database.getMetadatasFromOcIdsAsync(ocIds)

            setEditMode(false)
            await NCCreate().createActivityViewController(
                selectedMetadata: metadatas,
                controller: self.controller,
                presentViewController: self,
                sender: nil)
        }
    }

    func delete() {
        let ocIds = self.fileSelect.map { $0 }
        var alertStyle = UIAlertController.Style.actionSheet

        if UIDevice.current.userInterfaceIdiom == .pad {
            alertStyle = .alert
        }

        if !ocIds.isEmpty {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: alertStyle)

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_delete_selected_photos_", comment: ""), style: .destructive) { (_: UIAlertAction) in
                self.isEditMode = false
                Task {
                    await (self.navigationController as? NCMediaNavigationController)?.setNavigationRightItems()

                    for ocId in ocIds {
                        await self.deleteImage(with: ocId)
                    }
                    self.collectionViewReloadData()
                }
            })

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (_: UIAlertAction) in })

            present(alertController, animated: true, completion: { })
        }
    }

    func deleteImage(with ocId: String) async {
        guard let metadata = await self.database.getMetadataFromOcIdAsync(ocId) else {
            await MainActor.run {
                self.dataSource.removeCompactMetadata([ocId])
                self.collectionViewReloadData()
            }
            return
        }

        let resultsDeleteFileOrFolder = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: metadata.serverUrlFileName,
                                                                                            name: "deleteFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        guard resultsDeleteFileOrFolder.error == .success || resultsDeleteFileOrFolder.error.errorCode == self.global.errorResourceNotFound else {
            return
        }

        await self.database.deleteMetadataAsync(id: ocId)

        await MainActor.run {
            if let indexPath = self.dataSource.indexPath(forOcId: ocId) {
                self.collectionView.performBatchUpdates {
                    self.dataSource.removeCompactMetadata([ocId])
                    self.collectionView.deleteItems(at: [indexPath])
                }
            } else {
                self.dataSource.removeCompactMetadata([ocId])
                self.collectionViewReloadData()
            }
        }
    }
}
