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

import UIKit
import RealmSwift

// MARK: UICollectionViewDelegate
extension NCTrash: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let resultTableTrash = datasource?[indexPath.item] else { return }
        guard !isEditMode else {
            if let index = selectOcId.firstIndex(of: resultTableTrash.fileId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(resultTableTrash.fileId)
            }
            collectionView.reloadItems(at: [indexPath])
            tabBarSelect.update(selectOcId: selectOcId)
            return
        }

        if resultTableTrash.directory,
           let ncTrash: NCTrash = UIStoryboard(name: "NCTrash", bundle: nil).instantiateInitialViewController() as? NCTrash {
            ncTrash.filePath = resultTableTrash.filePath + resultTableTrash.fileName
            ncTrash.titleCurrentFolder = resultTableTrash.trashbinFileName
            ncTrash.filename = resultTableTrash.fileName
            self.navigationController?.pushViewController(ncTrash, animated: true)
        }
    }
}

// MARK: UICollectionViewDataSource
extension NCTrash: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return datasource?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var image: UIImage?
        var cell: NCTrashCellProtocol & UICollectionViewCell

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            let listCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCTrashListCell)!
            listCell.delegate = self
            cell = listCell
        } else {
            let gridCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCTrashGridCell)!
            gridCell.setButtonMore(image: NCImageCache.shared.getImageButtonMore())
            gridCell.delegate = self
            cell = gridCell
        }
        guard let resultTableTrash = datasource?[indexPath.item] else { return cell }

        cell.imageItem.contentMode = .scaleAspectFit

        if resultTableTrash.iconName.isEmpty {
            image = NCImageCache.shared.getImageFile()
        } else {
            image = NCUtility().loadImage(named: resultTableTrash.iconName, useTypeIconFile: true, account: resultTableTrash.account)
        }

        if let imageIcon = utility.getImage(ocId: resultTableTrash.fileId, etag: resultTableTrash.fileName, ext: NCGlobal.shared.previewExt512) {
            image = imageIcon
            cell.imageItem.contentMode = .scaleAspectFill
        } else {
            if resultTableTrash.hasPreview {
                if NCNetworking.shared.downloadThumbnailTrashQueue.operations.filter({ ($0 as? NCOperationDownloadThumbnailTrash)?.fileId == resultTableTrash.fileId }).isEmpty {
                    NCNetworking.shared.downloadThumbnailTrashQueue.addOperation(NCOperationDownloadThumbnailTrash(fileId: resultTableTrash.fileId, fileName: resultTableTrash.fileName, account: session.account, collectionView: collectionView))
                }
            }
        }

        cell.account = resultTableTrash.account
        cell.objectId = resultTableTrash.fileId
        cell.setupCellUI(tableTrash: resultTableTrash, image: image)
        cell.selected(selectOcId.contains(resultTableTrash.fileId), isEditMode: isEditMode, account: resultTableTrash.account)

        return cell
    }

    func setTextFooter(datasource: Results<tableTrash>) -> String {
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
            filesText = "\(files) " + NSLocalizedString("_files_", comment: "") + " " + utilityFileSystem.transformedSize(size)
        } else if files == 1 {
            filesText = "1 " + NSLocalizedString("_file_", comment: "") + " " + utilityFileSystem.transformedSize(size)
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
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeaderEmptyData", for: indexPath) as? NCSectionFirstHeaderEmptyData
            else { return NCSectionFirstHeaderEmptyData() }
            header.emptyImage.image = utility.loadImage(named: "trash", colors: [NCBrandColor.shared.getElement(account: session.account)])
            header.emptyTitle.text = NSLocalizedString("_trash_no_trash_", comment: "")
            header.emptyDescription.text = NSLocalizedString("_trash_no_trash_description_", comment: "")
            return header
        } else {
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter
            else { return NCSectionFooter() }
            if let datasource {
                footer.setTitleLabel(setTextFooter(datasource: datasource))
                footer.separatorIsHidden(true)
            }
            return footer
        }
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension NCTrash: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        var height: Double = 0
        if let datasource, datasource.isEmpty {
            height = utility.getHeightHeaderEmptyData(view: view, portraitOffset: 0, landscapeOffset: 0)
        }
        return CGSize(width: collectionView.frame.width, height: height)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 85)
    }
}
