// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import RealmSwift
import NextcloudKit

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

    func collectionView(_ collectionView: UICollectionView,
                        didEndDisplaying cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard let cell = cell as? NCTrashCellProtocol else {
            return
        }

        Task {
            await NCTransferCoordinator.shared.cancel(identifier: cell.identifier)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard let datasource,
              indexPath.item >= 0,
              indexPath.item < datasource.count else {
            return
        }
        let result = datasource[indexPath.item]
        let identifier = result.fileId
        let etag = result.fileName
        let iconName = result.iconName
        let imageExists = utilityFileSystem.fileProviderStorageImageExists(identifier, etag: etag, userId: self.session.userId, urlBase: self.session.urlBase)

        guard result.hasPreview,
              !imageExists else {
            return
        }

        Task {
            await NCTransferCoordinator.shared.start(
                identifier: identifier,
                priority: .visible
            ) {
                let result = await NextcloudKit.shared.downloadTrashPreviewAsync(
                    fileId: identifier,
                    account: self.session.account)

                guard !Task.isCancelled,
                      result.error == .success,
                      let data = result.responseData?.data else {
                    return
                }

                let image = await NCUtility().createImageFileFrom(
                    data: data,
                    ocId: identifier,
                    etag: etag,
                    ext: NCGlobal.shared.previewExt256,
                    userId: self.session.userId,
                    urlBase: self.session.urlBase)

                await MainActor.run {
                    guard let visibleIndexPath = collectionView.indexPathsForVisibleItems.first(where: { visibleIndexPath in
                        guard let fileId = self.datasource?[visibleIndexPath.item].fileId else {
                            return false
                        }
                        return String(fileId) == identifier
                    }),
                    let cell = collectionView.cellForItem(at: visibleIndexPath) as? NCTrashCellProtocol,
                        cell.identifier == identifier else {
                            return
                    }

                    if let image {
                        cell.image?.contentMode = .scaleAspectFill
                        UIView.transition(
                            with: cell.image,
                            duration: 0.75,
                            options: .transitionCrossDissolve
                        ) {
                            cell.image.image = image
                        }
                    } else {
                        cell.image.contentMode = .scaleAspectFit
                        cell.image.image = NCUtility().loadImage(
                            named: iconName,
                            useTypeIconFile: true,
                            account: self.session.account
                        )
                    }
                }
            }
        }
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

        let contextMenu = NCContextMenuTrash(objectId: resultTableTrash.fileId, trashController: self)
        if let listCell = cell as? NCTrashListCell {
            listCell.buttonMore.menu = contextMenu.viewMenu()
            listCell.buttonMore.showsMenuAsPrimaryAction = true
        } else if let gridCell = cell as? NCTrashGridCell {
            gridCell.buttonMore.menu = contextMenu.viewMenu()
            gridCell.buttonMore.showsMenuAsPrimaryAction = true
        }

        cell.image.contentMode = .scaleAspectFit

        if resultTableTrash.iconName.isEmpty {
            image = NCImageCache.shared.getImageFile()
        } else {
            image = NCUtility().loadImage(named: resultTableTrash.iconName, useTypeIconFile: true, account: resultTableTrash.account)
        }

        if let imageIcon = utility.getImage(ocId: resultTableTrash.fileId,
                                            etag: resultTableTrash.fileName,
                                            ext: NCGlobal.shared.previewExt512,
                                            userId: session.userId,
                                            urlBase: session.urlBase) {
            image = imageIcon
            cell.image.contentMode = .scaleAspectFill
        }

        cell.identifier = resultTableTrash.fileId
        cell.setupCellUI(tableTrash: resultTableTrash, image: image)
        cell.selected(selectOcId.contains(resultTableTrash.fileId), isEditMode: isEditMode, color: NCBrandColor.shared.getElement(account: session.account))

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
