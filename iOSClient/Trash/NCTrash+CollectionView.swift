//
//  NCTrash+CollectionView.swift
//  Nextcloud
//
//  Created by Henrik Storch on 18.01.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Foundation

// MARK: UICollectionViewDelegate
extension NCTrash {

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        let tableTrash = datasource[indexPath.item]

        guard !isEditMode else {
            if let index = selectOcId.firstIndex(of: tableTrash.fileId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(tableTrash.fileId)
            }
            collectionView.reloadItems(at: [indexPath])
            self.navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(datasource.count)"
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
extension NCTrash {

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {

            guard let trashHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as? NCTrashSectionHeaderMenu
            else { return UICollectionReusableView() }

            if collectionView.collectionViewLayout == gridLayout {
                trashHeader.buttonSwitch.setImage(UIImage(named: "switchList")?.image(color: NCBrandColor.shared.gray, size: 25), for: .normal)
            } else {
                trashHeader.buttonSwitch.setImage(UIImage(named: "switchGrid")?.image(color: NCBrandColor.shared.gray, size: 25), for: .normal)
            }

            trashHeader.delegate = self
            trashHeader.backgroundColor = NCBrandColor.shared.systemBackground
            trashHeader.separator.backgroundColor = NCBrandColor.shared.separator
            trashHeader.setStatusButton(datasource: datasource)
            trashHeader.setTitleSorted(datasourceTitleButton: layoutForView?.titleButtonHeader ?? "")

            return trashHeader

        } else {
            guard let trashFooter = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCTrashSectionFooter
            else { return UICollectionReusableView() }
            trashFooter.setTitleLabelFooter(datasource: datasource)
            return trashFooter
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        emptyDataSet?.numberOfItemsInSection(datasource.count, section: section)
        return datasource.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

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

        var cell: NCTrashCell & UICollectionViewCell

        if collectionView.collectionViewLayout == listLayout {
            guard let listCell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCTrashListCell else { return UICollectionViewCell() }
            cell = listCell
        } else {
            // GRID
            guard let gridCell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell else { return UICollectionViewCell() }
            gridCell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCBrandColor.cacheImages.buttonMore)
            cell = gridCell
        }

        cell.setupCellUI(tableTrash: tableTrash, image: image)
        cell.selectMode(isEditMode)
        if isEditMode {
            cell.selected(selectOcId.contains(tableTrash.fileId))
        }

        return cell
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension NCTrash {

    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: highHeader)
    }

    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: highHeader)
    }
}
