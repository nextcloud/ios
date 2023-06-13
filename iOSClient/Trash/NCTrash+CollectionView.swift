//
//  NCTrash+CollectionView.swift
//  Nextcloud
//
//  Created by Henrik Storch on 18.01.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
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

import Foundation

// MARK: UICollectionViewDelegate
extension NCTrash: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        let tableTrash = datasource[indexPath.item]

        guard !isEditMode else {
            if let index = selectOcId.firstIndex(of: tableTrash.fileId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(tableTrash.fileId)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }

        if tableTrash.directory,
           let ncTrash: NCTrash = UIStoryboard(name: "NCTrash", bundle: nil).instantiateInitialViewController() as? NCTrash {
            ncTrash.trashPath = tableTrash.filePath + tableTrash.fileName
            ncTrash.titleCurrentFolder = tableTrash.trashbinFileName
            self.navigationController?.pushViewController(ncTrash, animated: true)
        }
    }
}

// MARK: UICollectionViewDataSource
extension NCTrash: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        emptyDataSet?.numberOfItemsInSection(datasource.count, section: section)
        return datasource.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let tableTrash = datasource[indexPath.item]
        var image: UIImage?

        if tableTrash.iconName.isEmpty {
            image = UIImage(named: "file")
        } else {
            image = UIImage(named: tableTrash.iconName)
        }

        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)) {
            image = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName))
        } else {
            if tableTrash.hasPreview && !CCUtility.fileProviderStoragePreviewIconExists(tableTrash.fileId, etag: tableTrash.fileName) {
                downloadThumbnail(with: tableTrash, indexPath: indexPath)
            }
        }

        var cell: NCTrashCellProtocol & UICollectionViewCell

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            guard let listCell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCTrashListCell else { return UICollectionViewCell() }
            listCell.delegate = self
            cell = listCell
        } else {
            // GRID
            guard let gridCell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell else { return UICollectionViewCell() }
            gridCell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCBrandColor.cacheImages.buttonMore)
            gridCell.delegate = self
            cell = gridCell
        }

        cell.setupCellUI(tableTrash: tableTrash, image: image)
        cell.selectMode(isEditMode)
        if isEditMode {
            cell.selected(selectOcId.contains(tableTrash.fileId))
        }

        return cell
    }

    func setTextFooter(datasource: [tableTrash]) -> String {

        var folders: Int = 0, foldersText = ""
        var files: Int = 0, filesText = ""
        var size: Int64 = 0
        var text = ""

        for record: tableTrash in datasource {
            if record.directory {
                folders += 1
            } else {
                files += 1
                size += record.size
            }
        }

        if folders > 1 {
            foldersText = "\(folders) " + NSLocalizedString("_folders_", comment: "")
        } else if folders == 1 {
            foldersText = "1 " + NSLocalizedString("_folder_", comment: "")
        }

        if files > 1 {
            filesText = "\(files) " + NSLocalizedString("_files_", comment: "") + " " + CCUtility.transformedSize(size)
        } else if files == 1 {
            filesText = "1 " + NSLocalizedString("_file_", comment: "") + " " + CCUtility.transformedSize(size)
        }

        if foldersText.isEmpty {
            text = filesText
        } else if filesText.isEmpty {
            text = foldersText
        } else {
            text = foldersText + ", " + filesText
        }

        return text
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {

            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as? NCSectionHeaderMenu
            else { return UICollectionReusableView() }

            if layoutForView?.layout == NCGlobal.shared.layoutGrid {
                header.setImageSwitchList()
                header.buttonSwitch.accessibilityLabel = NSLocalizedString("_list_view_", comment: "")
            } else {
                header.setImageSwitchGrid()
                header.buttonSwitch.accessibilityLabel = NSLocalizedString("_grid_view_", comment: "")
            }

            header.delegate = self
            header.setStatusButtonsView(enable: !datasource.isEmpty)
            header.setSortedTitle(layoutForView?.titleButtonHeader ?? "")
            if isEditMode {
                header.setButtonsCommand(heigt: NCGlobal.shared.heightButtonsCommand,
                                         imageButton1: UIImage(named: "restore"), titleButton1: NSLocalizedString("_trash_restore_selected_", comment: ""),
                                         imageButton2: UIImage(named: "trash"), titleButton2: NSLocalizedString("_trash_delete_selected_", comment: ""))
            } else {
                header.setButtonsCommand(heigt: NCGlobal.shared.heightButtonsCommand,
                                         imageButton1: UIImage(named: "restore"), titleButton1: NSLocalizedString("_trash_restore_all_", comment: ""),
                                         imageButton2: UIImage(named: "trash"), titleButton2: NSLocalizedString("_trash_delete_all_", comment: ""))
            }
            header.setButtonsView(heigt: NCGlobal.shared.heightButtonsView)
            header.setRichWorkspaceHeight(0)
            header.setSectionHeight(0)

            return header

        } else {

            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter
            else { return UICollectionReusableView() }

            footer.setTitleLabel(setTextFooter(datasource: datasource))
            footer.separatorIsHidden(true)

            return footer
        }
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension NCTrash: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: NCGlobal.shared.heightButtonsView + NCGlobal.shared.heightButtonsCommand)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: NCGlobal.shared.endHeightFooter)
    }
}
