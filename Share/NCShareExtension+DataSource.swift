//
//  NCShareExtension+DataSource.swift
//  Share
//
//  Created by Henrik Storch on 29.12.21.
//  Copyright © 2021 Henrik Storch. All rights reserved.
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
import NextcloudKit

// MARK: - Collection View (target folder)

extension NCShareExtension: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return showAlert(description: "_invalid_url_") }
        let serverUrl = utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)
        if metadata.e2eEncrypted && !NCKeychain().isEndToEndEnabled(account: activeAccount.account) {
            showAlert(title: "_info_", description: "_e2e_goto_settings_for_enable_")
        }

        if let fileNameError = FileNameValidator.shared.checkFileName(metadata.fileNameView) {
            present(UIAlertController.warning(message: "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)
            return
        }

        self.serverUrl = serverUrl
        reloadDatasource(withLoadFolder: true)
        setNavigationBar(navigationTitle: metadata.fileNameView)
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeaderEmptyData", for: indexPath) as? NCSectionFirstHeaderEmptyData else { return NCSectionFirstHeaderEmptyData() }
            if self.dataSourceTask?.state == .running {
                header.emptyImage.image = utility.loadImage(named: "wifi", colors: [NCBrandColor.shared.brandElement])
                header.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
                header.emptyDescription.text = ""
            } else {
                header.emptyImage.image = NCImageCache.images.folder
                header.emptyTitle.text = NSLocalizedString("_files_no_folders_", comment: "")
                header.emptyDescription.text = ""
            }
            return header
        } else {
            return UICollectionReusableView()
        }
    }
}

extension NCShareExtension: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        var height: CGFloat = 0
        if dataSource.getMetadataSourceForAllSections().isEmpty {
            height = NCGlobal.shared.getHeightHeaderEmptyData(view: view, portraitOffset: 0, landscapeOffset: -50)
        }
        return CGSize(width: collectionView.frame.width, height: height)
    }
}

extension NCShareExtension: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath), let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell else {
            return UICollectionViewCell()
        }

        cell.fileObjectId = metadata.ocId
        cell.indexPath = indexPath
        cell.fileUser = metadata.ownerId
        cell.labelTitle.text = metadata.fileNameView
        cell.labelTitle.textColor = NCBrandColor.shared.textColor
        cell.imageSelect.image = nil
        cell.imageStatus.image = nil
        cell.imageLocal.image = nil
        cell.imageFavorite.image = nil
        cell.imageShared.image = nil
        cell.imageMore.image = nil
        cell.imageItem.image = nil
        cell.imageItem.backgroundColor = nil
        cell.progressView.progress = 0.0

        if metadata.directory {
            setupDirectoryCell(cell, indexPath: indexPath, with: metadata)
        }

        if metadata.favorite {
            cell.imageFavorite.image = NCImageCache.images.favorite
        }

        cell.imageSelect.isHidden = true
        cell.backgroundView = nil
        cell.hideButtonMore(true)
        cell.hideButtonShare(true)
        cell.selected(false, isEditMode: false)

        if metadata.isLivePhoto {
            cell.imageStatus.image = NCImageCache.images.livePhoto
        }

        cell.setTags(tags: Array(metadata.tags))

        cell.separator.isHidden = collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1

        return cell
    }

    func setupDirectoryCell(_ cell: NCListCell, indexPath: IndexPath, with metadata: tableMetadata) {
        var isShare = false
        var isMounted = false
        let permissions = NCPermissions()
        if let metadataFolder = metadataFolder {
            isShare = metadata.permissions.contains(permissions.permissionShared) && !metadataFolder.permissions.contains(permissions.permissionShared)
            isMounted = metadata.permissions.contains(permissions.permissionMounted) && !metadataFolder.permissions.contains(permissions.permissionMounted)
        }

        if metadata.e2eEncrypted {
            cell.imageItem.image = NCImageCache.images.folderEncrypted
        } else if isShare {
            cell.imageItem.image = NCImageCache.images.folderSharedWithMe
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(3) ?
            (cell.imageItem.image = NCImageCache.images.folderPublic) :
            (cell.imageItem.image = NCImageCache.images.folderSharedWithMe)
        } else if metadata.mountType == "group" {
            cell.imageItem.image = NCImageCache.images.folderGroup
        } else if isMounted {
            cell.imageItem.image = NCImageCache.images.folderExternal
        } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
            cell.imageItem.image = NCImageCache.images.folderAutomaticUpload
        } else {
            cell.imageItem.image = NCImageCache.images.folder
        }

        cell.labelInfo.text = utility.dateDiff(metadata.date as Date)

        let lockServerUrl = utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)
        let tableDirectory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", activeAccount.account, lockServerUrl))

        // Local image: offline
        if tableDirectory != nil && tableDirectory!.offline {
            cell.imageLocal.image = NCImageCache.images.offlineFlag
        }
    }
}

// MARK: - Table View (uploading files)

extension NCShareExtension: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return heightRowTableView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !uploadStarted else { return }
        let fileName = filesName[indexPath.row]
        renameFile(named: fileName)
    }
}

extension NCShareExtension: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filesName.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? NCShareCell else { return UITableViewCell() }
        let fileName = filesName[indexPath.row]
        cell.setup(fileName: fileName)
        cell.delegate = self
        return cell
    }
}
