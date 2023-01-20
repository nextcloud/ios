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
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath),
              let serverUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName) else {
                  return showAlert(description: "_invalid_url_")
              }

        if metadata.e2eEncrypted && !CCUtility.isEnd(toEndEnabled: activeAccount.account) {
            showAlert(title: "_info_", description: "_e2e_goto_settings_for_enable_")
        }

        self.serverUrl = serverUrl
        reloadDatasource(withLoadFolder: true)
        setNavigationBar(navigationTitle: metadata.fileNameView)
    }
}

extension NCShareExtension: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberOfItems = dataSource.numberOfItemsInSection(section)
        emptyDataSet?.numberOfItemsInSection(numberOfItems, section: section)
        return numberOfItems
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath), let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell else {
            return UICollectionViewCell()
        }

        cell.delegate = self

        cell.fileObjectId = metadata.ocId
        cell.fileUser = metadata.ownerId
        cell.labelTitle.text = metadata.fileNameView
        cell.labelTitle.textColor = .label

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

        // image Favorite
        if metadata.favorite {
            cell.imageFavorite.image = NCBrandColor.cacheImages.favorite
        }

        cell.imageSelect.isHidden = true
        cell.backgroundView = nil
        cell.hideButtonMore(true)
        cell.hideButtonShare(true)
        cell.selectMode(false)

        // Live Photo
        if metadata.livePhoto {
            cell.imageStatus.image = NCBrandColor.cacheImages.livePhoto
        }

        // Remove last separator
        cell.separator.isHidden = collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1

        return cell
    }

    func setupDirectoryCell(_ cell: NCListCell, indexPath: IndexPath, with metadata: tableMetadata) {
        var isShare = false
        var isMounted = false
        if let metadataFolder = metadataFolder {
            isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionShared)
            isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionMounted)
        }

        if metadata.e2eEncrypted {
            cell.imageItem.image = NCBrandColor.cacheImages.folderEncrypted
        } else if isShare {
            cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(3) ?
            (cell.imageItem.image = NCBrandColor.cacheImages.folderPublic) :
            (cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe)
        } else if metadata.mountType == "group" {
            cell.imageItem.image = NCBrandColor.cacheImages.folderGroup
        } else if isMounted {
            cell.imageItem.image = NCBrandColor.cacheImages.folderExternal
        } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
            cell.imageItem.image = NCBrandColor.cacheImages.folderAutomaticUpload
        } else {
            cell.imageItem.image = NCBrandColor.cacheImages.folder
        }

        cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date)

        let lockServerUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
        let tableDirectory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", activeAccount.account, lockServerUrl))

        // Local image: offline
        if tableDirectory != nil && tableDirectory!.offline {
            cell.imageLocal.image = NCBrandColor.cacheImages.offlineFlag
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
