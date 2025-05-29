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
        self.dataSource.getMetadata(indexPath: indexPath) { metadata in
            guard let metadata else { return self.showAlert(description: "_invalid_url_") }
            let serverUrl = self.utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)
            if metadata.e2eEncrypted && !NCKeychain().isEndToEndEnabled(account: self.session.account) {
                self.showAlert(title: "_info_", description: "_e2e_goto_settings_for_enable_")
            }

            if let fileNameError = FileNameValidator.checkFileName(metadata.fileNameView, account: self.session.account) {
                self.present(UIAlertController.warning(message: "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)
                return
            }

            self.serverUrl = serverUrl
            self.reloadDatasource(withLoadFolder: true)
            self.setNavigationBar(navigationTitle: metadata.fileNameView)
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeaderEmptyData", for: indexPath) as? NCSectionFirstHeaderEmptyData else { return NCSectionFirstHeaderEmptyData() }
            if self.dataSourceTask?.state == .running {
                header.emptyImage.image = utility.loadImage(named: "wifi", colors: [NCBrandColor.shared.getElement(account: session.account)])
                header.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
                header.emptyDescription.text = ""
            } else {
                header.emptyImage.image = NCImageCache.shared.getFolder(account: self.session.account)
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
        if self.dataSource.isEmpty() {
            height = NCUtility().getHeightHeaderEmptyData(view: view, portraitOffset: 0, landscapeOffset: -50)
        }
        return CGSize(width: collectionView.frame.width, height: height)
    }
}

extension NCShareExtension: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell)!
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else {
            return cell
        }

        cell.fileOcId = metadata.ocId
        cell.fileOcIdTransfer = metadata.ocIdTransfer
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

        if metadata.directory {
            setupDirectoryCell(cell, indexPath: indexPath, with: metadata)
        }

        if metadata.favorite {
            cell.imageFavorite.image = NCImageCache.shared.getImageFavorite()
        }

        cell.imageSelect.isHidden = true
        cell.backgroundView = nil
        cell.hideButtonMore(true)
        cell.hideButtonShare(true)
        cell.selected(false, isEditMode: false)

        if metadata.isLivePhoto {
            cell.imageStatus.image = utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor2])
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
            cell.imageItem.image = NCImageCache.shared.getFolderEncrypted(account: metadata.account)
        } else if isShare {
            cell.imageItem.image = NCImageCache.shared.getFolderSharedWithMe(account: metadata.account)
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(3) ?
            (cell.imageItem.image = NCImageCache.shared.getFolderPublic(account: metadata.account)) :
            (cell.imageItem.image = NCImageCache.shared.getFolderSharedWithMe(account: metadata.account))
        } else if metadata.mountType == "group" {
            cell.imageItem.image = NCImageCache.shared.getFolderGroup(account: metadata.account)
        } else if isMounted {
            cell.imageItem.image = NCImageCache.shared.getFolderExternal(account: metadata.account)
        } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
            cell.imageItem.image = NCImageCache.shared.getFolderAutomaticUpload(account: metadata.account)
        } else {
            cell.imageItem.image = NCImageCache.shared.getFolder(account: metadata.account)
        }

        cell.labelInfo.text = utility.getRelativeDateTitle(metadata.date as Date)

        let lockServerUrl = utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)
        let tableDirectory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, lockServerUrl))

        // Local image: offline
        if tableDirectory != nil && tableDirectory!.offline {
            cell.imageLocal.image = NCImageCache.shared.getImageOfflineFlag()
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
        showRenameFileDialog(named: fileName, account: session.account)
    }
}

extension NCShareExtension: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filesName.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? NCShareCell else { return UITableViewCell() }
        let fileName = filesName[indexPath.row]
        cell.setup(fileName: fileName, account: session.account)
        cell.delegate = self
        return cell
    }
}
