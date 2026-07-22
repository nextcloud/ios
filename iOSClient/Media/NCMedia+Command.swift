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
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems.sorted {
            if $0.section == $1.section {
                return $0.item < $1.item
            }
            return $0.section < $1.section
        }

        guard let firstIndexPath = visibleIndexPaths.first,
              let lastIndexPath = visibleIndexPaths.last,
              let firstMetadata = dataSource.getCompactMetadata(indexPath: firstIndexPath),
              let lastMetadata = dataSource.getCompactMetadata(indexPath: lastIndexPath) else {
            navigationItem.leftBarButtonItem = nil
            return
        }

        let firstDate = firstMetadata.date
        let lastDate = lastMetadata.date
        let calendar = Calendar.current

        let firstYear = calendar.component(.year, from: firstDate)
        let lastYear = calendar.component(.year, from: lastDate)

        let title: String

        if calendar.isDate(firstDate, inSameDayAs: lastDate) {
            title = firstDate.formatted(
                .dateTime
                    .day()
                    .month(.abbreviated)
                    .year()
            )
        } else if firstYear == lastYear {
            let firstDateTitle = firstDate.formatted(
                .dateTime
                    .day()
                    .month(.abbreviated)
            )

            let lastDateTitle = lastDate.formatted(
                .dateTime
                    .day()
                    .month(.abbreviated)
                    .year()
            )

            title = "\(firstDateTitle) – \(lastDateTitle)"
        } else {
            let firstDateTitle = firstDate.formatted(
                .dateTime
                    .day()
                    .month(.abbreviated)
                    .year()
            )

            let lastDateTitle = lastDate.formatted(
                .dateTime
                    .day()
                    .month(.abbreviated)
                    .year()
            )

            title = "\(firstDateTitle) – \(lastDateTitle)"
        }

        buttonDateBarItem.title = title

        if navigationItem.leftBarButtonItem !== buttonDateBarItem {
            navigationItem.leftBarButtonItem = buttonDateBarItem
        }
    }

    @objc func presentMediaDatePicker() {
        let viewController = NCMediaDatePickerViewController(
            availableYearMonths: dataSource.availableYearMonths,
            selectedYearMonth: currentVisibleYearMonth()
        )

        viewController.onDateSelected = { [weak self] yearMonth in
            self?.scrollToMedia(year: yearMonth.year, month: yearMonth.month)
        }

        if let sheet = viewController.sheetPresentationController {
            sheet.detents = [
                .custom(identifier: .init("mediaDatePicker")) { _ in
                    200
                }
            ]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }

        present(viewController, animated: true)
    }

    private func currentVisibleYearMonth() -> NCYearMonth? {
        let firstIndexPath = collectionView.indexPathsForVisibleItems.min {
            if $0.section == $1.section {
                return $0.item < $1.item
            }

            return $0.section < $1.section
        }

        guard let firstIndexPath,
              let metadata = dataSource.getCompactMetadata(indexPath: firstIndexPath) else {
            return nil
        }

        return NCYearMonth(date: metadata.date)
    }

    private func scrollToMedia(year: Int, month: Int) {
        guard let indexPath = dataSource.firstIndexPath(year: year, month: month) else {
            return
        }

        collectionView.layoutIfNeeded()

        guard let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath) else {
            return
        }

        let targetOffsetY = attributes.frame.minY - collectionView.adjustedContentInset.top

        collectionView.setContentOffset(
            CGPoint(x: collectionView.contentOffset.x, y: targetOffsetY),
            animated: false
        )

        collectionView.layoutIfNeeded()
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
            self.dataSource.removeCompactMetadata([ocId])
            self.collectionViewReloadData()
        }
    }
}
