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
        return self.dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath),
              let cell = (cell as? NCCellProtocol) else { return }
        let existsIcon = utility.existsImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.storageExt512x512)

        func downloadAvatar(fileName: String, user: String, dispalyName: String?) {
            if let image = database.getImageAvatarLoaded(fileName: fileName) {
                cell.fileAvatarImageView?.contentMode = .scaleAspectFill
                cell.fileAvatarImageView?.image = image
            } else {
                NCNetworking.shared.downloadAvatar(user: user, dispalyName: dispalyName, fileName: fileName, account: metadata.account, cell: cell, view: collectionView)
            }
        }
        /// CONTENT MODE
        cell.filePreviewImageView?.layer.borderWidth = 0
        if isLayoutPhoto {
            if metadata.isImageOrVideo, existsIcon {
                cell.filePreviewImageView?.contentMode = .scaleAspectFill
            } else {
                cell.filePreviewImageView?.contentMode = .scaleAspectFit
            }
        } else {
            if existsIcon {
                cell.filePreviewImageView?.contentMode = .scaleAspectFill
            } else {
                cell.filePreviewImageView?.contentMode = .scaleAspectFit
            }
        }
        cell.fileAvatarImageView?.contentMode = .center
        /// THUMBNAIL
        if !metadata.directory {
            if metadata.hasPreviewBorder {
                cell.filePreviewImageView?.layer.borderWidth = 0.2
                cell.filePreviewImageView?.layer.borderColor = UIColor.lightGray.cgColor
            }
            if metadata.name == global.appName {
                if isLayoutPhoto, metadata.isImageOrVideo {
                    if let image = NCImageCache.shared.getPreviewImageCache(ocId: metadata.ocId, etag: metadata.etag) {
                        cell.filePreviewImageView?.image = image
                    } else if let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.storageExt512x512) {
                        cell.filePreviewImageView?.image = image
                        NCImageCache.shared.addPreviewImageCache(metadata: metadata, image: image)
                    }
                } else {
                    if let image = NCImageCache.shared.getIconImageCache(ocId: metadata.ocId, etag: metadata.etag) {
                        cell.filePreviewImageView?.image = image
                    } else {
                        cell.filePreviewImageView?.image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.storageExt512x512)
                    }
                }
                if cell.filePreviewImageView?.image == nil {
                    if metadata.iconName.isEmpty {
                        cell.filePreviewImageView?.image = NCImageCache.shared.getImageFile()
                    } else {
                        cell.filePreviewImageView?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                    }
                    if metadata.hasPreview && metadata.status == global.metadataStatusNormal && !existsIcon {
                        for case let operation as NCCollectionViewDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId { return }
                        NCNetworking.shared.downloadThumbnailQueue.addOperation(NCCollectionViewDownloadThumbnail(metadata: metadata, collectionView: collectionView))
                    }
                }
            } else {
                /// APP NAME - UNIFIED SEARCH
                switch metadata.iconName {
                case let str where str.contains("contacts"):
                    cell.filePreviewImageView?.image = utility.loadImage(named: "person.crop.rectangle.stack", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("conversation"):
                    cell.filePreviewImageView?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
                case let str where str.contains("calendar"):
                    cell.filePreviewImageView?.image = utility.loadImage(named: "calendar", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("deck"):
                    cell.filePreviewImageView?.image = utility.loadImage(named: "square.stack.fill", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("mail"):
                    cell.filePreviewImageView?.image = utility.loadImage(named: "mail", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("talk"):
                    cell.filePreviewImageView?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
                case let str where str.contains("confirm"):
                    cell.filePreviewImageView?.image = utility.loadImage(named: "arrow.right", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("pages"):
                    cell.filePreviewImageView?.image = utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.iconImageColor])
                default:
                    cell.filePreviewImageView?.image = utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])
                }
                if !metadata.iconUrl.isEmpty {
                    if let ownerId = getAvatarFromIconUrl(metadata: metadata) {
                        let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: ownerId)
                        downloadAvatar(fileName: fileName, user: ownerId, dispalyName: nil)
                    }
                }
            }
        }
        /// AVATAR
        if !metadata.ownerId.isEmpty,
           metadata.ownerId != metadata.userId {
           // appDelegate.account == metadata.account {
            let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: metadata.ownerId)
            downloadAvatar(fileName: fileName, user: metadata.ownerId, dispalyName: metadata.ownerDisplayName)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else { return }
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
        let metadata = self.dataSource.getMetadata(indexPath: indexPath) ?? tableMetadata()

        // LAYOUT PHOTO
        if isLayoutPhoto {
            if metadata.isImageOrVideo {
                guard let photoCell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? NCPhotoCell else { return NCPhotoCell() }
                photoCell.photoCellDelegate = self
                cell = photoCell
            } else {
                guard let gridCell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell else { return NCGridCell() }
                gridCell.gridCellDelegate = self
                cell = gridCell
            }
        } else if isLayoutGrid {
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
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else { return cell }

        defer {
            if !metadata.isSharable() || NCCapabilities.shared.disableSharesView(account: metadata.account) {
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
        cell.fileAccount = metadata.account
        cell.fileOcId = metadata.ocId
        cell.fileOcIdTransfer = metadata.ocIdTransfer
        cell.fileUser = metadata.ownerId

        cell.hideImageItem(false)
        cell.hideImageFavorite(false)
        cell.hideImageStatus(false)
        cell.hideImageLocal(false)
        cell.hideLabelTitle(false)
        cell.hideLabelInfo(false)
        cell.hideLabelSubinfo(false)
        cell.hideButtonShare(false)
        cell.hideButtonMore(false)

        cell.titleInfoTrailingDefault()

        if isSearchingMode {
            cell.fileTitleLabel?.text = metadata.fileName
            cell.fileTitleLabel?.lineBreakMode = .byTruncatingTail
            if metadata.name == global.appName {
                cell.fileInfoLabel?.text = NSLocalizedString("_in_", comment: "") + " " + utilityFileSystem.getPath(path: metadata.path, user: metadata.user)
            } else {
                cell.fileInfoLabel?.text = metadata.subline
            }
            cell.fileSubinfoLabel?.isHidden = true
        } else if !metadata.sessionError.isEmpty, metadata.status != global.metadataStatusNormal {
            cell.fileSubinfoLabel?.isHidden = false
            cell.fileInfoLabel?.text = metadata.sessionError
        } else {
            cell.fileSubinfoLabel?.isHidden = false
            cell.fileTitleLabel?.text = metadata.fileNameView
            cell.fileTitleLabel?.lineBreakMode = .byTruncatingMiddle
            cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
        }

        // Accessibility [shared] if metadata.ownerId != appDelegate.userId, appDelegate.account == metadata.account {
        if metadata.ownerId != metadata.userId {
            a11yValues.append(NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName)
        }

        if metadata.directory {
            let tableDirectory = database.getTableDirectory(ocId: metadata.ocId)
            if metadata.e2eEncrypted {
                cell.filePreviewImageView?.image = NCImageCache.shared.getFolderEncrypted(account: metadata.account)
            } else if isShare {
                cell.filePreviewImageView?.image = NCImageCache.shared.getFolderSharedWithMe(account: metadata.account)
            } else if !metadata.shareType.isEmpty {
                metadata.shareType.contains(3) ?
                (cell.filePreviewImageView?.image = NCImageCache.shared.getFolderPublic(account: metadata.account)) :
                (cell.filePreviewImageView?.image = NCImageCache.shared.getFolderSharedWithMe(account: metadata.account))
            } else if !metadata.shareType.isEmpty && metadata.shareType.contains(3) {
                cell.filePreviewImageView?.image = NCImageCache.shared.getFolderPublic(account: metadata.account)
            } else if metadata.mountType == "group" {
                cell.filePreviewImageView?.image = NCImageCache.shared.getFolderGroup(account: metadata.account)
            } else if isMounted {
                cell.filePreviewImageView?.image = NCImageCache.shared.getFolderExternal(account: metadata.account)
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.filePreviewImageView?.image = NCImageCache.shared.getFolderAutomaticUpload(account: metadata.account)
            } else {
                cell.filePreviewImageView?.image = NCImageCache.shared.getFolder(account: metadata.account)
            }

            // Local image: offline
            if let tableDirectory, tableDirectory.offline {
                cell.fileLocalImage?.image = NCImageCache.shared.getImageOfflineFlag()
            }

            // color folder
            cell.filePreviewImageView?.image = cell.filePreviewImageView?.image?.colorizeFolder(metadata: metadata, tableDirectory: tableDirectory)
        } else {
            let tableLocalFile = database.getResultsTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))?.first
            // image local
            if let tableLocalFile, tableLocalFile.offline {
                a11yValues.append(NSLocalizedString("_offline_", comment: ""))
                cell.fileLocalImage?.image = NCImageCache.shared.getImageOfflineFlag()
            } else if utilityFileSystem.fileProviderStorageExists(metadata) {
                cell.fileLocalImage?.image = NCImageCache.shared.getImageLocal()
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.fileFavoriteImage?.image = NCImageCache.shared.getImageFavorite()
            a11yValues.append(NSLocalizedString("_favorite_short_", comment: ""))
        }

        // Share image
        if isShare {
            cell.fileSharedImage?.image = NCImageCache.shared.getImageShared()
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(3) ?
            (cell.fileSharedImage?.image = NCImageCache.shared.getImageShareByLink()) :
            (cell.fileSharedImage?.image = NCImageCache.shared.getImageShared())
        } else {
            cell.fileSharedImage?.image = NCImageCache.shared.getImageCanShare()
        }

        /*
        if appDelegate.account != metadata.account {
            cell.fileSharedImage?.image = NCImageCache.images.shared
        }
        */

        // Button More
        if metadata.lock == true {
            cell.setButtonMore(image: NCImageCache.shared.getImageButtonMoreLock())
            a11yValues.append(String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName))
        } else {
            cell.setButtonMore(image: NCImageCache.shared.getImageButtonMore())
        }

        /// Staus
        if metadata.isLivePhoto {
            cell.fileStatusImage?.image = utility.loadImage(named: "livephoto", colors: isLayoutPhoto ? [.white] : [NCBrandColor.shared.iconImageColor2])
            a11yValues.append(NSLocalizedString("_upload_mov_livephoto_", comment: ""))
        } else if metadata.isVideo {
            cell.fileStatusImage?.image = utility.loadImage(named: "play.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        }
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.fileStatusImage?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.fileStatusImage?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
        case NCGlobal.shared.metadataStatusWaitCreateFolder:
            cell.fileStatusImage?.image = utility.loadImage(named: "exclamationmark.arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
        case NCGlobal.shared.metadataStatusDownloading:
            if #available(iOS 17.0, *) {
                cell.fileStatusImage?.image = utility.loadImage(named: "arrowshape.down.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            }
        case NCGlobal.shared.metadataStatusUploading:
            if #available(iOS 17.0, *) {
                cell.fileStatusImage?.image = utility.loadImage(named: "arrowshape.up.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            }
        case NCGlobal.shared.metadataStatusDownloadError, NCGlobal.shared.metadataStatusUploadError:
            cell.fileStatusImage?.image = utility.loadImage(named: "exclamationmark.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        default:
            break
        }

        /// URL
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
            cell.selected(true, isEditMode: isEditMode, account: metadata.account)
            a11yValues.append(NSLocalizedString("_selected_", comment: ""))
        } else {
            cell.selected(false, isEditMode: isEditMode, account: metadata.account)
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

        // TAGS
        cell.setTags(tags: Array(metadata.tags))

        // Layout photo
        if isLayoutPhoto, sizeImage.width < 120 {
            cell.hideImageFavorite(true)
            cell.hideImageLocal(true)
            cell.fileTitleLabel?.font = UIFont.systemFont(ofSize: 10)
            if sizeImage.width < 100 {
                cell.hideImageItem(true)
                cell.hideButtonMore(true)
                cell.hideLabelInfo(true)
                cell.hideLabelSubinfo(true)
            }
        }

        // Hide buttons
        if metadata.name != global.appName {
            cell.titleInfoTrailingFull()
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
        }

        cell.setIconOutlines()
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader || kind == mediaSectionHeader {
            if self.dataSource.isEmpty() {
                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeaderEmptyData", for: indexPath) as? NCSectionFirstHeaderEmptyData else { return NCSectionFirstHeaderEmptyData() }
                self.sectionFirstHeaderEmptyData = header
                header.delegate = self

                if !isSearchingMode, headerMenuTransferView, isHeaderMenuTransferViewEnabled() != nil {
                    header.setViewTransfer(isHidden: false)
                } else {
                    header.setViewTransfer(isHidden: true)
                }

                if isSearchingMode {
                    header.emptyImage.image = utility.loadImage(named: "magnifyingglass", colors: [NCBrandColor.shared.getElement(account: session.account)])
                    if self.dataSourceTask?.state == .running {
                        header.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
                    } else {
                        header.emptyTitle.text = NSLocalizedString("_search_no_record_found_", comment: "")
                    }
                    header.emptyDescription.text = NSLocalizedString("_search_instruction_", comment: "")
                } else if self.dataSourceTask?.state == .running {
                    header.emptyImage.image = utility.loadImage(named: "wifi", colors: [NCBrandColor.shared.getElement(account: session.account)])
                    header.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
                    header.emptyDescription.text = ""
                } else {
                    if serverUrl.isEmpty {
                        if let emptyImageName {
                            header.emptyImage.image = utility.loadImage(named: emptyImageName, colors: emptyImageColors != nil ? emptyImageColors : [NCBrandColor.shared.getElement(account: session.account)])
                        } else {
                            header.emptyImage.image = NCImageCache.shared.getFolder(account: session.account)
                        }
                        header.emptyTitle.text = NSLocalizedString(emptyTitle, comment: "")
                        header.emptyDescription.text = NSLocalizedString(emptyDescription, comment: "")
                    } else {
                        header.emptyImage.image = NCImageCache.shared.getFolder(account: session.account)
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

                if !isSearchingMode, headerMenuTransferView, isHeaderMenuTransferViewEnabled() != nil {
                    header.setViewTransfer(isHidden: false)
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
            let sections = self.dataSource.numberOfSections()
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
                    let info = self.dataSource.getFooterInformation()
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
