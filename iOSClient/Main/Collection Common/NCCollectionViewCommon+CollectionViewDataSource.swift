//
//  NCCollectionViewCommon+CollectionViewDataSource.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
import UIKit
import NextcloudKit

extension NCCollectionViewCommon: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath),
              let cell = (cell as? NCCellProtocol) else { return }
        let existsIcon = utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)

        func downloadAvatar(fileName: String, user: String, dispalyName: String?) {
            if let image = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) {
                cell.fileAvatarImageView?.contentMode = .scaleAspectFill
                cell.fileAvatarImageView?.image = image
            } else {
                NCNetworking.shared.downloadAvatar(user: user, dispalyName: dispalyName, fileName: fileName, cell: cell, view: collectionView)
            }
        }
        /// CONTENT MODE
        cell.filePreviewImageView?.layer.borderWidth = 0
        if existsIcon {
            cell.filePreviewImageView?.contentMode = .scaleAspectFill
        } else {
            cell.filePreviewImageView?.contentMode = .scaleAspectFit
        }
        cell.fileAvatarImageView?.contentMode = .center
        /// THUMBNAIL
        if !metadata.directory {
            if metadata.hasPreviewBorder {
                cell.filePreviewImageView?.layer.borderWidth = 0.2
                cell.filePreviewImageView?.layer.borderColor = UIColor.lightGray.cgColor
            }
            if metadata.name == NCGlobal.shared.appName {
                if layoutForView?.layout == NCGlobal.shared.layoutPhotoRatio || layoutForView?.layout == NCGlobal.shared.layoutPhotoSquare {
                    if let image = NCImageCache.shared.getPreviewImageCache(ocId: metadata.ocId, etag: metadata.etag) {
                        cell.filePreviewImageView?.image = image
                    } else if let image = UIImage(contentsOfFile: self.utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)) {
                        cell.filePreviewImageView?.image = image
                        NCImageCache.shared.addPreviewImageCache(metadata: metadata, image: image)
                    }
                } else {
                    if let image = NCImageCache.shared.getIconImageCache(ocId: metadata.ocId, etag: metadata.etag) {
                        cell.filePreviewImageView?.image = image
                    } else if metadata.hasPreview {
                        cell.filePreviewImageView?.image = utility.getIcon(metadata: metadata)
                    }
                }
                if cell.filePreviewImageView?.image == nil {
                    if metadata.iconName.isEmpty {
                        cell.filePreviewImageView?.image = NCImageCache.images.file
                    } else {
                        cell.filePreviewImageView?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true)
                    }
                    if metadata.hasPreview && metadata.status == NCGlobal.shared.metadataStatusNormal && !existsIcon {
                        for case let operation as NCCollectionViewDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId { return }
                        NCNetworking.shared.downloadThumbnailQueue.addOperation(NCCollectionViewDownloadThumbnail(metadata: metadata, cell: cell, collectionView: collectionView))
                    }
                }
            } else {
                /// APP NAME - UNIFIED SEARCH
                switch metadata.iconName {
                case let str where str.contains("contacts"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconContacts
                case let str where str.contains("conversation"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconTalk
                case let str where str.contains("calendar"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconCalendar
                case let str where str.contains("deck"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconDeck
                case let str where str.contains("mail"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconMail
                case let str where str.contains("talk"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconTalk
                case let str where str.contains("confirm"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconConfirm
                case let str where str.contains("pages"):
                    cell.filePreviewImageView?.image = NCImageCache.images.iconPages
                default:
                    cell.filePreviewImageView?.image = NCImageCache.images.iconFile
                }
                if !metadata.iconUrl.isEmpty {
                    if let ownerId = getAvatarFromIconUrl(metadata: metadata) {
                        let fileName = metadata.userBaseUrl + "-" + ownerId + ".png"
                        downloadAvatar(fileName: fileName, user: ownerId, dispalyName: nil)
                    }
                }
            }
        }
        /// AVATAR
        if !metadata.ownerId.isEmpty,
           metadata.ownerId != appDelegate.userId,
           appDelegate.account == metadata.account {
            let fileName = metadata.userBaseUrl + "-" + metadata.ownerId + ".png"
            downloadAvatar(fileName: fileName, user: metadata.ownerId, dispalyName: metadata.ownerDisplayName)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }
            for case let operation as NCCollectionViewDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId {
                operation.cancel()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: NCCellProtocol & UICollectionViewCell
        let permissions = NCPermissions()
        var isShare = false
        var isMounted = false
        var a11yValues: [String] = []

        // LAYOUT PHOTO
        if layoutForView?.layout == NCGlobal.shared.layoutPhotoRatio || layoutForView?.layout == NCGlobal.shared.layoutPhotoSquare {
            guard let photoCell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? NCPhotoCell else { return NCPhotoCell() }
            photoCell.photoCellDelegate = self
            cell = photoCell
        } else if layoutForView?.layout == NCGlobal.shared.layoutGrid {
        // LAYOUT GRID
            guard let gridCell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell else { return NCGridCell() }
            gridCell.gridCellDelegate = self
            cell = gridCell
        } else {
        // LAYOUT LIST
            guard let listCell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell else { return NCListCell() }
            listCell.listCellDelegate = self
            cell = listCell
        }
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return cell }

        defer {
            if NCGlobal.shared.disableSharesView || !metadata.isSharable() {
                cell.hideButtonShare(true)
            }
        }

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(permissions.permissionShared) && !metadataFolder!.permissions.contains(permissions.permissionShared)
            isMounted = metadata.permissions.contains(permissions.permissionMounted) && !metadataFolder!.permissions.contains(permissions.permissionMounted)
        }

        cell.fileStatusImage?.image = nil
        cell.fileLocalImage?.image = nil
        cell.fileFavoriteImage?.image = nil
        cell.fileSharedImage?.image = nil
        cell.fileMoreImage?.image = nil
        cell.filePreviewImageView?.image = nil
        cell.filePreviewImageView?.backgroundColor = nil
        cell.fileObjectId = metadata.ocId
        cell.indexPath = indexPath
        cell.fileUser = metadata.ownerId
        cell.fileProgressView?.isHidden = true
        cell.fileProgressView?.progress = 0.0
        cell.hideButtonShare(false)
        cell.hideButtonMore(false)
        cell.titleInfoTrailingDefault()

        if isSearchingMode {
            cell.fileTitleLabel?.text = metadata.fileName
            cell.fileTitleLabel?.lineBreakMode = .byTruncatingTail
            if metadata.name == NCGlobal.shared.appName {
                cell.fileInfoLabel?.text = NSLocalizedString("_in_", comment: "") + " " + utilityFileSystem.getPath(path: metadata.path, user: metadata.user)
            } else {
                cell.fileInfoLabel?.text = metadata.subline
            }
            cell.fileSubinfoLabel?.isHidden = true
        } else {
            cell.fileSubinfoLabel?.isHidden = false
            cell.fileTitleLabel?.text = metadata.fileNameView
            cell.fileTitleLabel?.lineBreakMode = .byTruncatingMiddle
            cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
        }

        if metadata.status == NCGlobal.shared.metadataStatusDownloading || metadata.status == NCGlobal.shared.metadataStatusUploading {
            cell.fileProgressView?.isHidden = false
        }

        // Accessibility [shared]
        if metadata.ownerId != appDelegate.userId, appDelegate.account == metadata.account {
            a11yValues.append(NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName)
        }

        if metadata.directory {
            let tableDirectory = NCManageDatabase.shared.getTableDirectory(ocId: metadata.ocId)
            if metadata.e2eEncrypted {
                cell.filePreviewImageView?.image = NCImageCache.images.folderEncrypted
            } else if isShare {
                cell.filePreviewImageView?.image = NCImageCache.images.folderSharedWithMe
            } else if !metadata.shareType.isEmpty {
                metadata.shareType.contains(3) ?
                (cell.filePreviewImageView?.image = NCImageCache.images.folderPublic) :
                (cell.filePreviewImageView?.image = NCImageCache.images.folderSharedWithMe)
            } else if !metadata.shareType.isEmpty && metadata.shareType.contains(3) {
                cell.filePreviewImageView?.image = NCImageCache.images.folderPublic
            } else if metadata.mountType == "group" {
                cell.filePreviewImageView?.image = NCImageCache.images.folderGroup
            } else if isMounted {
                cell.filePreviewImageView?.image = NCImageCache.images.folderExternal
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.filePreviewImageView?.image = NCImageCache.images.folderAutomaticUpload
            } else {
                cell.filePreviewImageView?.image = NCImageCache.images.folder
            }

            // Local image: offline
            if let tableDirectory, tableDirectory.offline {
                cell.fileLocalImage?.image = NCImageCache.images.offlineFlag
            }

            // color folder
            cell.filePreviewImageView?.image = cell.filePreviewImageView?.image?.colorizeFolder(metadata: metadata, tableDirectory: tableDirectory)
        } else {
            let tableLocalFile = NCManageDatabase.shared.getResultsTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))?.first
            // image local
            if let tableLocalFile, tableLocalFile.offline {
                a11yValues.append(NSLocalizedString("_offline_", comment: ""))
                cell.fileLocalImage?.image = NCImageCache.images.offlineFlag
            } else if utilityFileSystem.fileProviderStorageExists(metadata) {
                cell.fileLocalImage?.image = NCImageCache.images.local
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.fileFavoriteImage?.image = NCImageCache.images.favorite
            a11yValues.append(NSLocalizedString("_favorite_short_", comment: ""))
        }

        // Share image
        if isShare {
            cell.fileSharedImage?.image = NCImageCache.images.shared
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(3) ?
            (cell.fileSharedImage?.image = NCImageCache.images.shareByLink) :
            (cell.fileSharedImage?.image = NCImageCache.images.shared)
        } else {
            cell.fileSharedImage?.image = NCImageCache.images.canShare
        }
        if appDelegate.account != metadata.account {
            cell.fileSharedImage?.image = NCImageCache.images.shared
        }

        // Button More
        if metadata.isInTransfer || metadata.isWaitingTransfer {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCImageCache.images.buttonStop)
        } else if metadata.lock == true {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreLock, image: NCImageCache.images.buttonMoreLock)
            a11yValues.append(String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName))
        } else {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCImageCache.images.buttonMore)
        }

        // Write status on Label Info
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size)
            cell.fileSubinfoLabel?.text = infoLabelsSeparator + NSLocalizedString("_status_wait_download_", comment: "")
        case NCGlobal.shared.metadataStatusDownloading:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size)
            cell.fileSubinfoLabel?.text = infoLabelsSeparator + "↓ …"
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size)
            cell.fileSubinfoLabel?.text = infoLabelsSeparator + NSLocalizedString("_status_wait_upload_", comment: "")
            cell.fileLocalImage?.image = nil
        case NCGlobal.shared.metadataStatusUploading:
            cell.fileInfoLabel?.text = utilityFileSystem.transformedSize(metadata.size)
            cell.fileSubinfoLabel?.text = infoLabelsSeparator + "↑ …"
            cell.fileLocalImage?.image = nil
        case NCGlobal.shared.metadataStatusUploadError:
            if metadata.sessionError.isEmpty {
                cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_upload_", comment: "")
            } else {
                cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_upload_", comment: "") + " " + metadata.sessionError
            }
        default:
            break
        }

        // Live Photo
        if metadata.isLivePhoto {
            cell.fileStatusImage?.image = NCImageCache.images.livePhoto
            a11yValues.append(NSLocalizedString("_upload_mov_livephoto_", comment: ""))
        }

        // URL
        if metadata.classFile == NKCommon.TypeClassFile.url.rawValue {
            cell.fileLocalImage?.image = nil
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
            if let ownerId = getAvatarFromIconUrl(metadata: metadata) {
                cell.fileUser = ownerId
            }
        }

        // Separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 || isSearchingMode {
            cell.cellSeparatorView?.isHidden = true
        } else {
            cell.cellSeparatorView?.isHidden = false
        }

        // Edit mode
        if selectOcId.contains(metadata.ocId) {
            cell.selected(true, isEditMode: isEditMode)
            a11yValues.append(NSLocalizedString("_selected_", comment: ""))
        } else {
            cell.selected(false, isEditMode: isEditMode)
        }

        // Accessibility
        cell.setAccessibility(label: metadata.fileNameView + ", " + (cell.fileInfoLabel?.text ?? "") + (cell.fileSubinfoLabel?.text ?? ""), value: a11yValues.joined(separator: ", "))

        // Color string find in search
        cell.fileTitleLabel?.textColor = NCBrandColor.shared.textColor
        cell.fileTitleLabel?.font = .systemFont(ofSize: 15)

        if isSearchingMode, let literalSearch = self.literalSearch, let title = cell.fileTitleLabel?.text {
            let longestWordRange = (title.lowercased() as NSString).range(of: literalSearch)
            let attributedString = NSMutableAttributedString(string: title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15)])
            attributedString.setAttributes([NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 15), NSAttributedString.Key.foregroundColor: UIColor.systemBlue], range: longestWordRange)
            cell.fileTitleLabel?.attributedText = attributedString
        }

        // Layout photo
        if layoutForView?.layout == NCGlobal.shared.layoutPhotoRatio || layoutForView?.layout == NCGlobal.shared.layoutPhotoSquare {
            if metadata.directory {
                cell.filePreviewImageBottom?.constant = 10
                cell.fileTitleLabel?.text = metadata.fileNameView
            } else {
                cell.filePreviewImageBottom?.constant = 0
                cell.fileTitleLabel?.text = ""
            }
        }

        // TAGS
        cell.setTags(tags: Array(metadata.tags))

        // Hide buttons
        if metadata.name != NCGlobal.shared.appName {
            cell.titleInfoTrailingFull()
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
        }

        cell.setIconOutlines()
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader || kind == mediaSectionHeader {

            if dataSource.getMetadataSourceForAllSections().isEmpty {

                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeaderEmptyData", for: indexPath) as? NCSectionFirstHeaderEmptyData else { return NCSectionFirstHeaderEmptyData() }
                self.sectionFirstHeaderEmptyData = header
                header.delegate = self

                if !isSearchingMode, headerMenuTransferView, let ocId = NCNetworking.shared.transferInForegorund?.ocId {
                    let text = String(format: NSLocalizedString("_upload_foreground_msg_", comment: ""), NCBrandOptions.shared.brand)
                    header.setViewTransfer(isHidden: false, ocId: ocId, text: text, progress: NCNetworking.shared.transferInForegorund?.progress)
                } else {
                    header.setViewTransfer(isHidden: true)
                }

                if isSearchingMode {
                    header.emptyImage.image = utility.loadImage(named: "magnifyingglass", colors: [NCBrandColor.shared.brandElement])
                    if self.dataSourceTask?.state == .running {
                        header.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
                    } else {
                        header.emptyTitle.text = NSLocalizedString("_search_no_record_found_", comment: "")
                    }
                    header.emptyDescription.text = NSLocalizedString("_search_instruction_", comment: "")
                } else if self.dataSourceTask?.state == .running {
                    header.emptyImage.image = utility.loadImage(named: "wifi", colors: [NCBrandColor.shared.brandElement])
                    header.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
                    header.emptyDescription.text = ""
                } else {
                    if serverUrl.isEmpty {
                        header.emptyImage.image = emptyImage
                        header.emptyTitle.text = NSLocalizedString(emptyTitle, comment: "")
                        header.emptyDescription.text = NSLocalizedString(emptyDescription, comment: "")
                    } else {
                        header.emptyImage.image = NCImageCache.images.folder
                        header.emptyTitle.text = NSLocalizedString("_files_no_files_", comment: "")
                        header.emptyDescription.text = NSLocalizedString("_no_file_pull_down_", comment: "")
                    }
                }

                return header

            } else if indexPath.section == 0 {

                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeader", for: indexPath) as? NCSectionFirstHeader else { return NCSectionFirstHeader() }
                let (_, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: indexPath.section)
                self.sectionFirstHeader = header
                header.delegate = self

                if !isSearchingMode, headerMenuTransferView, let ocId = NCNetworking.shared.transferInForegorund?.ocId {
                    let text = String(format: NSLocalizedString("_upload_foreground_msg_", comment: ""), NCBrandOptions.shared.brand)
                    header.setViewTransfer(isHidden: false, ocId: ocId, text: text, progress: NCNetworking.shared.transferInForegorund?.progress)
                } else {
                    header.setViewTransfer(isHidden: true)
                }

                header.setRichWorkspaceHeight(heightHeaderRichWorkspace)
                header.setRichWorkspaceText(richWorkspaceText)

                header.setSectionHeight(heightHeaderSection)
                if heightHeaderSection == 0 {
                    header.labelSection.text = ""
                } else {
                    header.labelSection.text = self.dataSource.getSectionValueLocalization(indexPath: indexPath)
                }
                header.labelSection.textColor = NCBrandColor.shared.textColor

                return header

            } else {

                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as? NCSectionHeader else { return NCSectionHeader() }

                header.labelSection.text = self.dataSource.getSectionValueLocalization(indexPath: indexPath)
                header.labelSection.textColor = NCBrandColor.shared.textColor

                return header
            }

        } else {

            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter else { return NCSectionFooter() }
            let sections = dataSource.numberOfSections()
            let section = indexPath.section
            let metadataForSection = self.dataSource.getMetadataForSection(indexPath.section)
            let isPaginated = metadataForSection?.lastSearchResult?.isPaginated ?? false
            let metadatasCount: Int = metadataForSection?.metadatas.count ?? 0
            let unifiedSearchInProgress = metadataForSection?.unifiedSearchInProgress ?? false

            footer.delegate = self
            footer.metadataForSection = metadataForSection

            footer.setTitleLabel("")
            footer.setButtonText(NSLocalizedString("_show_more_results_", comment: ""))
            footer.separatorIsHidden(true)
            footer.buttonIsHidden(true)
            footer.hideActivityIndicatorSection()

            if isSearchingMode {
                if sections > 1 && section != sections - 1 {
                    footer.separatorIsHidden(false)
                }

                // If the number of entries(metadatas) is lower than the cursor, then there are no more entries.
                // The blind spot in this is when the number of entries is the same as the cursor. If so, we don't have a way of knowing if there are no more entries.
                // This is as good as it gets for determining last page without server-side flag.
                let isLastPage = (metadatasCount < metadataForSection?.lastSearchResult?.cursor ?? 0) || metadataForSection?.lastSearchResult?.entries.isEmpty == true

                if isSearchingMode && isPaginated && metadatasCount > 0 && !isLastPage {
                    footer.buttonIsHidden(false)
                }

                if unifiedSearchInProgress {
                    footer.showActivityIndicatorSection()
                }
            } else {
                if sections == 1 || section == sections - 1 {
                    let info = dataSource.getFooterInformationAllMetadatas()
                    footer.setTitleLabel(directories: info.directories, files: info.files, size: info.size)
                } else {
                    footer.separatorIsHidden(false)
                }
            }

            return footer
        }
    }

    // MARK: -

    func getAvatarFromIconUrl(metadata: tableMetadata) -> String? {
        var ownerId: String?

        if metadata.iconUrl.contains("http") && metadata.iconUrl.contains("avatar") {
            let splitIconUrl = metadata.iconUrl.components(separatedBy: "/")
            var found: Bool = false
            for item in splitIconUrl {
                if found {
                    ownerId = item
                    break
                }
                if item == "avatar" { found = true}
            }
        }
        return ownerId
    }
}
