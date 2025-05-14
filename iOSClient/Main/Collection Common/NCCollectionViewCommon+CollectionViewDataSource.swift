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
import RealmSwift

extension NCCollectionViewCommon: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // get auto upload folder
        self.autoUploadFileName = self.database.getAccountAutoUploadFileName(account: self.session.account)
        self.autoUploadDirectory = self.database.getAccountAutoUploadDirectory(session: self.session)
        // get layout for view
        self.layoutForView = self.database.getLayoutForView(account: self.session.account, key: self.layoutKey, serverUrl: self.serverUrl)

        return self.dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else { return }
            for case let operation as NCCollectionViewDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId {
                        operation.cancel()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.getMetadata(indexPath: indexPath) else { return }
        let existsImagePreview = utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag)
        let ext = global.getSizeExtension(column: self.numberOfColumns)

        if metadata.hasPreview,
           !existsImagePreview,
           NCNetworking.shared.downloadThumbnailQueue.operations.filter({ ($0 as? NCMediaDownloadThumbnail)?.metadata.ocId == metadata.ocId }).isEmpty {
            NCNetworking.shared.downloadThumbnailQueue.addOperation(NCCollectionViewDownloadThumbnail(metadata: metadata, collectionView: collectionView, ext: ext))
        }
    }

    private func photoCell(cell: NCPhotoCell, indexPath: IndexPath, metadata: tableMetadata, ext: String) -> NCPhotoCell {
        let width = UIScreen.main.bounds.width / CGFloat(self.numberOfColumns)

        cell.ocId = metadata.ocId
        cell.ocIdTransfer = metadata.ocIdTransfer
        cell.hideButtonMore(true)
        cell.hideImageStatus(true)

        /// Image
        ///
        if let image = NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {

            cell.filePreviewImageView?.image = image
            cell.filePreviewImageView?.contentMode = .scaleAspectFill

        } else {

            if isPinchGestureActive || ext == global.previewExt512 || ext == global.previewExt1024 {
                cell.filePreviewImageView?.image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext)
            }

            DispatchQueue.global(qos: .userInteractive).async {
                let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext)
                if let image {
                    self.imageCache.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: ext, cost: indexPath.row)
                    DispatchQueue.main.async {
                        cell.filePreviewImageView?.image = image
                        cell.filePreviewImageView?.contentMode = .scaleAspectFill
                    }
                } else {
                    DispatchQueue.main.async {
                        cell.filePreviewImageView?.contentMode = .scaleAspectFit
                        if metadata.iconName.isEmpty {
                            cell.filePreviewImageView?.image = NCImageCache.shared.getImageFile()
                        } else {
                            cell.filePreviewImageView?.image = self.utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                        }
                    }
                }
            }
        }

        /// Status
        ///
        if metadata.isLivePhoto {
            cell.fileStatusImage?.image = utility.loadImage(named: "livephoto", colors: isLayoutPhoto ? [.white] : [NCBrandColor.shared.iconImageColor2])
        } else if metadata.isVideo {
            cell.fileStatusImage?.image = utility.loadImage(named: "play.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        }

        /// Edit mode
        if fileSelect.contains(metadata.ocId) {
            cell.selected(true, isEditMode: isEditMode)
        } else {
            cell.selected(false, isEditMode: isEditMode)
        }

        if width > 100 {
            cell.hideButtonMore(false)
            cell.hideImageStatus(false)
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: NCCellProtocol & UICollectionViewCell
        let permissions = NCPermissions()
        var isShare = false
        var isMounted = false
        var a11yValues: [String] = []
        let metadata = self.dataSource.getMetadata(indexPath: indexPath) ?? tableMetadata()
        let existsImagePreview = utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag)
        let ext = global.getSizeExtension(column: self.numberOfColumns)

        defer {
            if !metadata.isSharable() || NCCapabilities.shared.disableSharesView(account: metadata.account) {
                cell.hideButtonShare(true)
            }
        }

        // E2EE create preview
        if self.isDirectoryEncrypted,
           metadata.isImageOrVideo,
           !utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag) {
            utility.createImageFileFrom(metadata: metadata)
        }

        // LAYOUT PHOTO
        if isLayoutPhoto {
            if metadata.isImageOrVideo {
                let photoCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? NCPhotoCell)!
                photoCell.photoCellDelegate = self
                cell = photoCell
                return self.photoCell(cell: photoCell, indexPath: indexPath, metadata: metadata, ext: ext)
            } else {
                let gridCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell)!
                gridCell.gridCellDelegate = self
                cell = gridCell
            }
        } else if isLayoutGrid {
            // LAYOUT GRID
            let gridCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell)!
            gridCell.gridCellDelegate = self
            cell = gridCell
        } else {
            // LAYOUT LIST
            let listCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell)!
            listCell.listCellDelegate = self
            cell = listCell
        }

        /// CONTENT MODE
        cell.fileAvatarImageView?.contentMode = .center
        cell.filePreviewImageView?.layer.borderWidth = 0

        if existsImagePreview && layoutForView?.layout != global.layoutPhotoRatio {
            cell.filePreviewImageView?.contentMode = .scaleAspectFill
        } else {
            cell.filePreviewImageView?.contentMode = .scaleAspectFit
        }

        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else { return cell }

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(permissions.permissionShared) && !metadataFolder!.permissions.contains(permissions.permissionShared)
            isMounted = metadata.permissions.contains(permissions.permissionMounted) && !metadataFolder!.permissions.contains(permissions.permissionMounted)
        }

        cell.fileAccount = metadata.account
        cell.fileOcId = metadata.ocId
        cell.fileOcIdTransfer = metadata.ocIdTransfer
        cell.fileUser = metadata.ownerId

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
                cell.filePreviewImageView?.image = imageCache.getFolderEncrypted(account: metadata.account)
            } else if isShare {
                cell.filePreviewImageView?.image = imageCache.getFolderSharedWithMe(account: metadata.account)
            } else if !metadata.shareType.isEmpty {
                metadata.shareType.contains(3) ?
                (cell.filePreviewImageView?.image = imageCache.getFolderPublic(account: metadata.account)) :
                (cell.filePreviewImageView?.image = imageCache.getFolderSharedWithMe(account: metadata.account))
            } else if !metadata.shareType.isEmpty && metadata.shareType.contains(3) {
                cell.filePreviewImageView?.image = imageCache.getFolderPublic(account: metadata.account)
            } else if metadata.mountType == "group" {
                cell.filePreviewImageView?.image = imageCache.getFolderGroup(account: metadata.account)
            } else if isMounted {
                cell.filePreviewImageView?.image = imageCache.getFolderExternal(account: metadata.account)
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.filePreviewImageView?.image = imageCache.getFolderAutomaticUpload(account: metadata.account)
            } else {
                cell.filePreviewImageView?.image = imageCache.getFolder(account: metadata.account)
            }

            // Local image: offline
            if let tableDirectory, tableDirectory.offline {
                cell.fileLocalImage?.image = imageCache.getImageOfflineFlag()
            }

            // color folder
            cell.filePreviewImageView?.image = cell.filePreviewImageView?.image?.colorizeFolder(metadata: metadata, tableDirectory: tableDirectory)

        } else {

            if metadata.hasPreviewBorder {
                cell.filePreviewImageView?.layer.borderWidth = 0.2
                cell.filePreviewImageView?.layer.borderColor = UIColor.lightGray.cgColor
            }

            if metadata.name == global.appName {
                if let image = NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
                    cell.filePreviewImageView?.image = image
                } else if let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
                    cell.filePreviewImageView?.image = image
                }

                if cell.filePreviewImageView?.image == nil {
                    if metadata.iconName.isEmpty {
                        cell.filePreviewImageView?.image = NCImageCache.shared.getImageFile()
                    } else {
                        cell.filePreviewImageView?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
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
                        let results = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName)
                        if results.image == nil {
                            cell.filePreviewImageView?.image = utility.loadUserImage(for: ownerId, displayName: nil, urlBase: metadata.urlBase)
                        } else {
                            cell.filePreviewImageView?.image = results.image
                        }
                        if !(results.tblAvatar?.loaded ?? false),
                           NCNetworking.shared.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                            NCNetworking.shared.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: ownerId, fileName: fileName, account: metadata.account, view: collectionView, isPreviewImageView: true))
                        }
                    }
                }
            }

            let tableLocalFile = database.getResultsTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))?.first
            // image local
            if let tableLocalFile, tableLocalFile.offline {
                a11yValues.append(NSLocalizedString("_offline_", comment: ""))
                cell.fileLocalImage?.image = imageCache.getImageOfflineFlag()
            } else if utilityFileSystem.fileProviderStorageExists(metadata) {
                cell.fileLocalImage?.image = imageCache.getImageLocal()
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.fileFavoriteImage?.image = imageCache.getImageFavorite()
            a11yValues.append(NSLocalizedString("_favorite_short_", comment: ""))
        }

        // Share image
        if isShare {
            cell.fileSharedImage?.image = imageCache.getImageShared()
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(3) ?
            (cell.fileSharedImage?.image = imageCache.getImageShareByLink()) :
            (cell.fileSharedImage?.image = imageCache.getImageShared())
        } else {
            cell.fileSharedImage?.image = imageCache.getImageCanShare()
        }

        // Button More
        if metadata.lock == true {
            cell.setButtonMore(image: imageCache.getImageButtonMoreLock())
            a11yValues.append(String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName))
        } else {
            cell.setButtonMore(image: imageCache.getImageButtonMore())
        }

        // Staus
        if metadata.isLivePhoto {
            cell.fileStatusImage?.image = utility.loadImage(named: "livephoto", colors: isLayoutPhoto ? [.white] : [NCBrandColor.shared.iconImageColor2])
            a11yValues.append(NSLocalizedString("_upload_mov_livephoto_", comment: ""))
        } else if metadata.isVideo {
            cell.fileStatusImage?.image = utility.loadImage(named: "play.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        }
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitCreateFolder:
            cell.fileStatusImage?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_create_folder_", comment: "")
        case NCGlobal.shared.metadataStatusWaitFavorite:
            cell.fileStatusImage?.image = utility.loadImage(named: "star.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_favorite_", comment: "")
        case NCGlobal.shared.metadataStatusWaitCopy:
            cell.fileStatusImage?.image = utility.loadImage(named: "c.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_copy_", comment: "")
        case NCGlobal.shared.metadataStatusWaitMove:
            cell.fileStatusImage?.image = utility.loadImage(named: "m.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_move_", comment: "")
        case NCGlobal.shared.metadataStatusWaitRename:
            cell.fileStatusImage?.image = utility.loadImage(named: "a.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.fileInfoLabel?.text = NSLocalizedString("_status_wait_rename_", comment: "")
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.fileStatusImage?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
        case NCGlobal.shared.metadataStatusDownloading:
            if #available(iOS 17.0, *) {
                cell.fileStatusImage?.image = utility.loadImage(named: "arrowshape.down.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            }
        case NCGlobal.shared.metadataStatusDownloadError, NCGlobal.shared.metadataStatusUploadError:
            cell.fileStatusImage?.image = utility.loadImage(named: "exclamationmark.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        default:
            break
        }

        // AVATAR
        if !metadata.ownerId.isEmpty, metadata.ownerId != metadata.userId {
            cell.fileAvatarImageView?.contentMode = .scaleAspectFill

            let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: metadata.ownerId)
            let results = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName)

            if results.image == nil {
                cell.fileAvatarImageView?.image = utility.loadUserImage(for: metadata.ownerId, displayName: metadata.ownerDisplayName, urlBase: metadata.urlBase)
            } else {
                cell.fileAvatarImageView?.image = results.image
            }

            if !(results.tblAvatar?.loaded ?? false),
               NCNetworking.shared.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                NCNetworking.shared.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: metadata.ownerId, fileName: fileName, account: metadata.account, view: collectionView))
            }
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
        if fileSelect.contains(metadata.ocId) {
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

        // TAGS
        cell.setTags(tags: Array(metadata.tags))

        // Layout photo
        if isLayoutPhoto {
            let width = UIScreen.main.bounds.width / CGFloat(self.numberOfColumns)

            cell.hideImageFavorite(false)
            cell.hideImageLocal(false)
            cell.hideImageItem(false)
            cell.hideButtonMore(false)
            cell.hideLabelInfo(false)
            cell.hideLabelSubinfo(false)
            cell.hideImageStatus(false)
            cell.fileTitleLabel?.font = UIFont.systemFont(ofSize: 15)

            if width < 120 {
                cell.hideImageFavorite(true)
                cell.hideImageLocal(true)
                cell.fileTitleLabel?.font = UIFont.systemFont(ofSize: 10)
                if width < 100 {
                    cell.hideImageItem(true)
                    cell.hideButtonMore(true)
                    cell.hideLabelInfo(true)
                    cell.hideLabelSubinfo(true)
                    cell.hideImageStatus(true)
                }
            }
        }

        // Hide buttons
        if metadata.name != global.appName {
            cell.titleInfoTrailingFull()
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
        }

        cell.setIconOutlines()

        cell.accessibilityLabel = metadata.fileName
        cell.accessibilityIdentifier = "Cell/\(metadata.fileName)"

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        func setContent(header: UICollectionReusableView, indexPath: IndexPath) {
            let (heightHeaderRichWorkspace, heightHeaderRecommendations, heightHeaderSection) = getHeaderHeight(section: indexPath.section)

            if let header = header as? NCSectionFirstHeader {
                let recommendations = self.database.getRecommendedFiles(account: self.session.account)
                var sectionText = NSLocalizedString("_all_files_", comment: "")

                if NCKeychain().getPersonalFilesOnly(account: session.account) {
                    sectionText = NSLocalizedString("_personal_files_", comment: "")
                }

                if !self.dataSource.getSectionValueLocalization(indexPath: indexPath).isEmpty {
                    sectionText = self.dataSource.getSectionValueLocalization(indexPath: indexPath)
                }

                header.setContent(heightHeaderRichWorkspace: heightHeaderRichWorkspace,
                                  richWorkspaceText: richWorkspaceText,
                                  heightHeaderRecommendations: heightHeaderRecommendations,
                                  recommendations: recommendations,
                                  heightHeaderSection: heightHeaderSection,
                                  sectionText: sectionText,
                                  viewController: self,
                                  delegate: self)

            } else if let header = header as? NCSectionFirstHeaderEmptyData {
                var emptyImage: UIImage?
                var emptyTitle: String?

                if isSearchingMode {
                    emptyImage = utility.loadImage(named: "magnifyingglass", colors: [NCBrandColor.shared.getElement(account: session.account)])
                    if self.dataSourceTask?.state == .running {
                        emptyTitle = NSLocalizedString("_search_in_progress_", comment: "")
                    } else {
                        emptyTitle = NSLocalizedString("_search_no_record_found_", comment: "")
                    }
                    emptyDescription = NSLocalizedString("_search_instruction_", comment: "")
                } else if self.dataSourceTask?.state == .running {
                    emptyImage = utility.loadImage(named: "wifi", colors: [NCBrandColor.shared.getElement(account: session.account)])
                    emptyTitle = NSLocalizedString("_request_in_progress_", comment: "")
                    emptyDescription = ""
                } else {
                    if serverUrl.isEmpty {
                        if let emptyImageName {
                            emptyImage = utility.loadImage(named: emptyImageName, colors: emptyImageColors != nil ? emptyImageColors : [NCBrandColor.shared.getElement(account: session.account)])
                        } else {
                            emptyImage = imageCache.getFolder(account: session.account)
                        }
                        emptyTitle = NSLocalizedString(self.emptyTitle, comment: "")
                        emptyDescription = NSLocalizedString(emptyDescription, comment: "")
                    } else if self.metadataFolder?.status == global.metadataStatusWaitCreateFolder {
                        emptyImage = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: [NCBrandColor.shared.getElement(account: session.account)])
                        emptyTitle = NSLocalizedString("_files_no_files_", comment: "")
                        emptyDescription = NSLocalizedString("_folder_offline_desc_", comment: "")
                    } else {
                        emptyImage = imageCache.getFolder(account: session.account)
                        emptyTitle = NSLocalizedString("_files_no_files_", comment: "")
                        emptyDescription = NSLocalizedString("_no_file_pull_down_", comment: "")
                    }
                }

                header.setContent(emptyImage: emptyImage,
                                  emptyTitle: emptyTitle,
                                  emptyDescription: emptyDescription,
                                  delegate: self)

            } else if let header = header as? NCSectionHeader {
                let text = self.dataSource.getSectionValueLocalization(indexPath: indexPath)

                header.setContent(text: text)
            }
        }

        if kind == UICollectionView.elementKindSectionHeader || kind == mediaSectionHeader {
            if self.dataSource.isEmpty() {
                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeaderEmptyData", for: indexPath) as? NCSectionFirstHeaderEmptyData else { return NCSectionFirstHeaderEmptyData() }

                self.sectionFirstHeaderEmptyData = header
                setContent(header: header, indexPath: indexPath)

                return header

            } else if indexPath.section == 0 {
                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeader", for: indexPath) as? NCSectionFirstHeader else { return NCSectionFirstHeader() }

                self.sectionFirstHeader = header
                setContent(header: header, indexPath: indexPath)

                return header

            } else {
                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as? NCSectionHeader else { return NCSectionHeader() }

                setContent(header: header, indexPath: indexPath)

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
