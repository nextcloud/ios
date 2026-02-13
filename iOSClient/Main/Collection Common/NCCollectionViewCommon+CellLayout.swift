// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

extension NCCollectionViewCommon {
    // MARK: - LAYOUT PHOTO
    //
    internal func photoCell(cell: NCPhotoCell, indexPath: IndexPath, metadata: tableMetadata) -> NCPhotoCell {
        defer {
            let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
            if !metadata.isSharable() || (!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty) {
                cell.hideButtonShare(true)
            }
        }
        let width = UIScreen.main.bounds.width / CGFloat(self.numberOfColumns)
        let ext = global.getSizeExtension(column: self.numberOfColumns)


        cell.metadata = metadata
        // cell.hideButtonMore(true) NO MORE USED
        cell.hideImageStatus(true)

        // Image
        //
        if let image = NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {

            cell.previewImageView?.image = image
            cell.previewImageView?.contentMode = .scaleAspectFill

        } else {

            if isPinchGestureActive || ext == global.previewExt512 || ext == global.previewExt1024 {
                cell.previewImageView?.image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase)
            }

            DispatchQueue.global(qos: .userInteractive).async {
                let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase)
                if let image {
                    self.imageCache.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: ext, cost: indexPath.row)
                    DispatchQueue.main.async {
                        cell.previewImageView?.image = image
                        cell.previewImageView?.contentMode = .scaleAspectFill
                    }
                } else {
                    DispatchQueue.main.async {
                        cell.previewImageView?.contentMode = .scaleAspectFit
                        if metadata.iconName.isEmpty {
                            cell.previewImageView?.image = NCImageCache.shared.getImageFile()
                        } else {
                            cell.previewImageView?.image = self.utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                        }
                    }
                }
            }
        }

        // Edit mode
        //
        if fileSelect.contains(metadata.ocId) {
            cell.selected(true, isEditMode: isEditMode)
        } else {
            cell.selected(false, isEditMode: isEditMode)
        }

        if width > 100 {
            // cell.hideButtonMore(false) NO MORE USED
            cell.hideImageStatus(false)
        }

        return cell
    }

    // MARK: - LAYOUT GRID
    //
    internal func gridCell(cell: NCGridCell, indexPath: IndexPath, metadata: tableMetadata) -> NCGridCell {
        defer {
            let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
            if !metadata.isSharable() || (!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty) {
                cell.hideButtonShare(true)
            }
        }
        var isShare = false
        var isMounted = false
        var a11yValues: [String] = []
        let ext = global.getSizeExtension(column: self.numberOfColumns)
        let existsImagePreview = utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase)

        // CONTENT MODE
        cell.avatarImageView?.contentMode = .center
        cell.previewImageView?.layer.borderWidth = 0

        if existsImagePreview && layoutForView?.layout != global.layoutPhotoRatio {
            cell.previewImageView?.contentMode = .scaleAspectFill
        } else {
            cell.previewImageView?.contentMode = .scaleAspectFit
        }

        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else {
            return cell
        }

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(NCMetadataPermissions.permissionShared) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionShared)
            isMounted = metadata.permissions.contains(NCMetadataPermissions.permissionMounted) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionMounted)
        }

        if isSearchingMode {
            if metadata.name == global.appName {
                cell.info?.text = NSLocalizedString("_in_", comment: "") + " " + utilityFileSystem.getPath(path: metadata.path, user: metadata.user)
            } else {
                cell.info?.text = metadata.subline
            }
            cell.subInfo?.isHidden = true
        } else if !metadata.sessionError.isEmpty, metadata.status != global.metadataStatusNormal {
            cell.subInfo?.isHidden = false
            cell.info?.text = metadata.sessionError
        } else {
            cell.subInfo?.isHidden = false
            cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
        }

        cell.title?.text = metadata.fileNameView

        // Accessibility [shared] if metadata.ownerId != appDelegate.userId, appDelegate.account == metadata.account {
        if metadata.ownerId != metadata.userId {
            a11yValues.append(NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName)
        }

        if metadata.directory {
            let tblDirectory = database.getTableDirectory(ocId: metadata.ocId)

            if metadata.e2eEncrypted {
                cell.previewImageView?.image = imageCache.getFolderEncrypted(account: metadata.account)
            } else if isShare {
                cell.previewImageView?.image = imageCache.getFolderSharedWithMe(account: metadata.account)
            } else if !metadata.shareType.isEmpty {
                metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) ?
                (cell.previewImageView?.image = imageCache.getFolderPublic(account: metadata.account)) :
                (cell.previewImageView?.image = imageCache.getFolderSharedWithMe(account: metadata.account))
            } else if !metadata.shareType.isEmpty && metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) {
                cell.previewImageView?.image = imageCache.getFolderPublic(account: metadata.account)
            } else if metadata.mountType == "group" {
                cell.previewImageView?.image = imageCache.getFolderGroup(account: metadata.account)
            } else if isMounted {
                cell.previewImageView?.image = imageCache.getFolderExternal(account: metadata.account)
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.previewImageView?.image = imageCache.getFolderAutomaticUpload(account: metadata.account)
            } else {
                cell.previewImageView?.image = imageCache.getFolder(account: metadata.account)
            }

            // Local image: offline
            metadata.isOffline = tblDirectory?.offline ?? false

            if metadata.isOffline {
                cell.localImageView?.image = imageCache.getImageOfflineFlag(colors: [.systemBackground, .systemGreen])
            }

            // color folder
            cell.previewImageView?.image = cell.previewImageView?.image?.colorizeFolder(metadata: metadata, tblDirectory: tblDirectory)

        } else {
            let tableLocalFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

            if metadata.hasPreviewBorder {
                cell.previewImageView?.layer.borderWidth = 0.2
                cell.previewImageView?.layer.borderColor = UIColor.lightGray.cgColor
            }

            if metadata.name == global.appName {
                if let image = NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
                    cell.previewImageView?.image = image
                } else if let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase) {
                    cell.previewImageView?.image = image
                }

                if cell.previewImageView?.image == nil {
                    if metadata.iconName.isEmpty {
                        cell.previewImageView?.image = NCImageCache.shared.getImageFile()
                    } else {
                        cell.previewImageView?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                    }
                }
            } else {
                // APP NAME - UNIFIED SEARCH
                switch metadata.iconName {
                case let str where str.contains("contacts"):
                    cell.previewImageView?.image = utility.loadImage(named: "person.crop.rectangle.stack", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("conversation"):
                    cell.previewImageView?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
                case let str where str.contains("calendar"):
                    cell.previewImageView?.image = utility.loadImage(named: "calendar", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("deck"):
                    cell.previewImageView?.image = utility.loadImage(named: "square.stack.fill", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("mail"):
                    cell.previewImageView?.image = utility.loadImage(named: "mail", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("talk"):
                    cell.previewImageView?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
                case let str where str.contains("confirm"):
                    cell.previewImageView?.image = utility.loadImage(named: "arrow.right", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("pages"):
                    cell.previewImageView?.image = utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.iconImageColor])
                default:
                    cell.previewImageView?.image = utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])
                }
                if !metadata.iconUrl.isEmpty {
                    if let ownerId = getAvatarFromIconUrl(metadata: metadata) {
                        let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: ownerId)
                        if let image = NCImageCache.shared.getImageCache(key: fileName) {
                            cell.previewImageView?.image = image
                        } else {
                            self.database.getImageAvatarLoaded(fileName: fileName) { image, tblAvatar in
                                if let image {
                                    cell.previewImageView?.image = image
                                    NCImageCache.shared.addImageCache(image: image, key: fileName)
                                } else {
                                    cell.previewImageView?.image = self.utility.loadUserImage(for: ownerId, displayName: nil, urlBase: metadata.urlBase)
                                }

                                if !(tblAvatar?.loaded ?? false),
                                   self.networking.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                                    self.networking.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: ownerId, fileName: fileName, account: metadata.account, view: self.collectionView, isPreviewImageView: true))
                                }
                            }
                        }
                    }
                }
            }

            // Local image: offline
            metadata.isOffline = tableLocalFile?.offline ?? false

            if metadata.isOffline {
                a11yValues.append(NSLocalizedString("_offline_", comment: ""))
                cell.localImageView?.image = imageCache.getImageOfflineFlag(colors: [.systemBackground, .systemGreen])
            } else if utilityFileSystem.fileProviderStorageExists(metadata) {
                cell.localImageView?.image = imageCache.getImageLocal(colors: [.systemBackground, .systemGreen])
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.favoriteImageView?.image = imageCache.getImageFavorite()
            a11yValues.append(NSLocalizedString("_favorite_short_", comment: ""))
        }

        // Share image
        if isShare {
            cell.shareImageView?.image = imageCache.getImageShared()
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) ?
            (cell.shareImageView?.image = imageCache.getImageShareByLink()) :
            (cell.shareImageView?.image = imageCache.getImageShared())
        } else {
            cell.shareImageView?.image = imageCache.getImageCanShare()
        }

        // Button More
        if metadata.lock == true {
            cell.setButtonMore(image: imageCache.getImageButtonMoreLock())
            a11yValues.append(String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName))
        } else {
            cell.setButtonMore(image: imageCache.getImageButtonMore())
        }

        // Status
        if metadata.isLivePhoto {
            cell.statusImageView?.image = utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor])
            a11yValues.append(NSLocalizedString("_upload_mov_livephoto_", comment: ""))
        } else if metadata.isVideo {
            cell.statusImageView?.image = utility.loadImage(named: "play.circle.fill", colors: [.systemBackgroundInverted, .systemGray5])
        }

        switch metadata.status {
        case global.metadataStatusWaitCreateFolder:
            cell.statusImageView?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.info?.text = NSLocalizedString("_status_wait_create_folder_", comment: "")
        case global.metadataStatusWaitFavorite:
            cell.statusImageView?.image = utility.loadImage(named: "star.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.info?.text = NSLocalizedString("_status_wait_favorite_", comment: "")
        case global.metadataStatusWaitCopy:
            cell.statusImageView?.image = utility.loadImage(named: "c.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.info?.text = NSLocalizedString("_status_wait_copy_", comment: "")
        case global.metadataStatusWaitMove:
            cell.statusImageView?.image = utility.loadImage(named: "m.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.info?.text = NSLocalizedString("_status_wait_move_", comment: "")
        case global.metadataStatusWaitRename:
            cell.statusImageView?.image = utility.loadImage(named: "a.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.info?.text = NSLocalizedString("_status_wait_rename_", comment: "")
        case global.metadataStatusWaitDownload:
            cell.statusImageView?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
        case global.metadataStatusDownloading:
            cell.statusImageView?.image = utility.loadImage(named: "arrowshape.down.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        case global.metadataStatusDownloadError, global.metadataStatusUploadError:
            cell.statusImageView?.image = utility.loadImage(named: "exclamationmark.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        default:
            break
        }

        // AVATAR
        if !metadata.ownerId.isEmpty, metadata.ownerId != metadata.userId {
            let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: metadata.ownerId)
            if let image = NCImageCache.shared.getImageCache(key: fileName) {
                cell.avatarImageView?.contentMode = .scaleAspectFill
                cell.avatarImageView?.image = image
            } else {
                self.database.getImageAvatarLoaded(fileName: fileName) { image, tblAvatar in
                    if let image {
                        cell.avatarImageView?.contentMode = .scaleAspectFill
                        cell.avatarImageView?.image = image
                        NCImageCache.shared.addImageCache(image: image, key: fileName)
                    } else {
                        cell.avatarImageView?.contentMode = .scaleAspectFill
                        cell.avatarImageView?.image = self.utility.loadUserImage(for: metadata.ownerId, displayName: metadata.ownerDisplayName, urlBase: metadata.urlBase)
                    }

                    if !(tblAvatar?.loaded ?? false),
                       self.networking.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                        self.networking.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: metadata.ownerId, fileName: fileName, account: metadata.account, view: self.collectionView))
                    }
                }
            }
        }

        // URL
        if metadata.classFile == NKTypeClassFile.url.rawValue {
            cell.localImageView?.image = nil
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
        }

        // Separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 || isSearchingMode {
            cell.separatorView?.isHidden = true
        } else {
            cell.separatorView?.isHidden = false
        }

        // Edit mode
        if fileSelect.contains(metadata.ocId) {
            cell.selected(true, isEditMode: isEditMode)
            a11yValues.append(NSLocalizedString("_selected_", comment: ""))
        } else {
            cell.selected(false, isEditMode: isEditMode)
        }

        // Accessibility
        cell.setAccessibility(label: metadata.fileNameView + ", " + (cell.info?.text ?? "") + (cell.subInfo?.text ?? ""), value: a11yValues.joined(separator: ", "))

        // Color string find in search
        cell.title?.textColor = NCBrandColor.shared.textColor
        cell.title?.font = .systemFont(ofSize: 15)

        if isSearchingMode,
           let searchResultStore,
           let title = cell.title?.text {
            let longestWordRange = (title.lowercased() as NSString).range(of: searchResultStore)
            let attributedString = NSMutableAttributedString(string: title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15)])
            attributedString.setAttributes([NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 15), NSAttributedString.Key.foregroundColor: UIColor.systemBlue], range: longestWordRange)
            cell.title?.attributedText = attributedString
        }

        // TAGS
        cell.setTags(tags: Array(metadata.tags))

        // SearchingMode - TAG Separator Hidden
        if isSearchingMode {
            cell.tagSeparator?.isHidden = true
        }

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
            cell.title?.font = UIFont.systemFont(ofSize: 15)

            if width < 120 {
                cell.hideImageFavorite(true)
                cell.hideImageLocal(true)
                cell.title?.font = UIFont.systemFont(ofSize: 10)
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

        // Obligatory here, at the end !!
        cell.metadata = metadata

        return cell
    }

    // MARK: - LAYOUT LIST
    //
    internal func listCell(cell: NCListCell, indexPath: IndexPath, metadata: tableMetadata) -> NCListCell {
        defer {
            let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
            if !metadata.isSharable() || (!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty) {
                cell.hideButtonShare(true)
            }
        }
        var isShare = false
        var isMounted = false
        var a11yValues: [String] = []
        let ext = global.getSizeExtension(column: self.numberOfColumns)
        let existsImagePreview = utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase)

        // CONTENT MODE
        cell.avatarImageView?.contentMode = .center
        cell.previewImageView?.layer.borderWidth = 0

        if existsImagePreview && layoutForView?.layout != global.layoutPhotoRatio {
            cell.previewImageView?.contentMode = .scaleAspectFill
        } else {
            cell.previewImageView?.contentMode = .scaleAspectFit
        }

        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else {
            return cell
        }

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(NCMetadataPermissions.permissionShared) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionShared)
            isMounted = metadata.permissions.contains(NCMetadataPermissions.permissionMounted) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionMounted)
        }

        if isSearchingMode {
            if metadata.name == global.appName {
                cell.info?.text = NSLocalizedString("_in_", comment: "") + " " + utilityFileSystem.getPath(path: metadata.path, user: metadata.user)
            } else {
                cell.info?.text = metadata.subline
            }
            cell.subInfo?.isHidden = true
        } else if !metadata.sessionError.isEmpty, metadata.status != global.metadataStatusNormal {
            cell.subInfo?.isHidden = false
            cell.info?.text = metadata.sessionError
        } else {
            cell.subInfo?.isHidden = false
            cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
        }

        cell.title?.text = metadata.fileNameView

        // Accessibility [shared] if metadata.ownerId != appDelegate.userId, appDelegate.account == metadata.account {
        if metadata.ownerId != metadata.userId {
            a11yValues.append(NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName)
        }

        if metadata.directory {
            let tblDirectory = database.getTableDirectory(ocId: metadata.ocId)

            if metadata.e2eEncrypted {
                cell.previewImageView?.image = imageCache.getFolderEncrypted(account: metadata.account)
            } else if isShare {
                cell.previewImageView?.image = imageCache.getFolderSharedWithMe(account: metadata.account)
            } else if !metadata.shareType.isEmpty {
                metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) ?
                (cell.previewImageView?.image = imageCache.getFolderPublic(account: metadata.account)) :
                (cell.previewImageView?.image = imageCache.getFolderSharedWithMe(account: metadata.account))
            } else if !metadata.shareType.isEmpty && metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) {
                cell.previewImageView?.image = imageCache.getFolderPublic(account: metadata.account)
            } else if metadata.mountType == "group" {
                cell.previewImageView?.image = imageCache.getFolderGroup(account: metadata.account)
            } else if isMounted {
                cell.previewImageView?.image = imageCache.getFolderExternal(account: metadata.account)
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.previewImageView?.image = imageCache.getFolderAutomaticUpload(account: metadata.account)
            } else {
                cell.previewImageView?.image = imageCache.getFolder(account: metadata.account)
            }

            // Local image: offline
            metadata.isOffline = tblDirectory?.offline ?? false

            if metadata.isOffline {
                cell.localImageView?.image = imageCache.getImageOfflineFlag(colors: [.systemBackground, .systemGreen])
            }

            // color folder
            cell.previewImageView?.image = cell.previewImageView?.image?.colorizeFolder(metadata: metadata, tblDirectory: tblDirectory)

        } else {
            let tableLocalFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

            if metadata.hasPreviewBorder {
                cell.previewImageView?.layer.borderWidth = 0.2
                cell.previewImageView?.layer.borderColor = UIColor.lightGray.cgColor
            }

            if metadata.name == global.appName {
                if let image = NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
                    cell.previewImageView?.image = image
                } else if let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase) {
                    cell.previewImageView?.image = image
                }

                if cell.previewImageView?.image == nil {
                    if metadata.iconName.isEmpty {
                        cell.previewImageView?.image = NCImageCache.shared.getImageFile()
                    } else {
                        cell.previewImageView?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                    }
                }
            } else {
                // APP NAME - UNIFIED SEARCH
                switch metadata.iconName {
                case let str where str.contains("contacts"):
                    cell.previewImageView?.image = utility.loadImage(named: "person.crop.rectangle.stack", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("conversation"):
                    cell.previewImageView?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
                case let str where str.contains("calendar"):
                    cell.previewImageView?.image = utility.loadImage(named: "calendar", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("deck"):
                    cell.previewImageView?.image = utility.loadImage(named: "square.stack.fill", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("mail"):
                    cell.previewImageView?.image = utility.loadImage(named: "mail", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("talk"):
                    cell.previewImageView?.image = UIImage(named: "talk-template")!.image(color: NCBrandColor.shared.getElement(account: metadata.account))
                case let str where str.contains("confirm"):
                    cell.previewImageView?.image = utility.loadImage(named: "arrow.right", colors: [NCBrandColor.shared.iconImageColor])
                case let str where str.contains("pages"):
                    cell.previewImageView?.image = utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.iconImageColor])
                default:
                    cell.previewImageView?.image = utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])
                }
                if !metadata.iconUrl.isEmpty {
                    if let ownerId = getAvatarFromIconUrl(metadata: metadata) {
                        let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: ownerId)
                        if let image = NCImageCache.shared.getImageCache(key: fileName) {
                            cell.previewImageView?.image = image
                        } else {
                            self.database.getImageAvatarLoaded(fileName: fileName) { image, tblAvatar in
                                if let image {
                                    cell.previewImageView?.image = image
                                    NCImageCache.shared.addImageCache(image: image, key: fileName)
                                } else {
                                    cell.previewImageView?.image = self.utility.loadUserImage(for: ownerId, displayName: nil, urlBase: metadata.urlBase)
                                }

                                if !(tblAvatar?.loaded ?? false),
                                   self.networking.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                                    self.networking.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: ownerId, fileName: fileName, account: metadata.account, view: self.collectionView, isPreviewImageView: true))
                                }
                            }
                        }
                    }
                }
            }

            // Local image: offline
            metadata.isOffline = tableLocalFile?.offline ?? false

            if metadata.isOffline {
                a11yValues.append(NSLocalizedString("_offline_", comment: ""))
                cell.localImageView?.image = imageCache.getImageOfflineFlag(colors: [.systemBackground, .systemGreen])
            } else if utilityFileSystem.fileProviderStorageExists(metadata) {
                cell.localImageView?.image = imageCache.getImageLocal(colors: [.systemBackground, .systemGreen])
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.favoriteImageView?.image = imageCache.getImageFavorite()
            a11yValues.append(NSLocalizedString("_favorite_short_", comment: ""))
        }

        // Share image
        if isShare {
            cell.shareImageView?.image = imageCache.getImageShared()
        } else if !metadata.shareType.isEmpty {
            metadata.shareType.contains(NKShare.ShareType.publicLink.rawValue) ?
            (cell.shareImageView?.image = imageCache.getImageShareByLink()) :
            (cell.shareImageView?.image = imageCache.getImageShared())
        } else {
            cell.shareImageView?.image = imageCache.getImageCanShare()
        }

        // Button More
        if metadata.lock == true {
            cell.setButtonMore(image: imageCache.getImageButtonMoreLock())
            a11yValues.append(String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName))
        } else {
            cell.setButtonMore(image: imageCache.getImageButtonMore())
        }

        // Status
        if metadata.isLivePhoto {
            cell.statusImageView?.image = utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor])
            a11yValues.append(NSLocalizedString("_upload_mov_livephoto_", comment: ""))
        } else if metadata.isVideo {
            cell.statusImageView?.image = utility.loadImage(named: "play.circle.fill", colors: [.systemBackgroundInverted, .systemGray5])
        }

        switch metadata.status {
        case global.metadataStatusWaitCreateFolder:
            cell.statusImageView?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.info?.text = NSLocalizedString("_status_wait_create_folder_", comment: "")
        case global.metadataStatusWaitFavorite:
            cell.statusImageView?.image = utility.loadImage(named: "star.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.info?.text = NSLocalizedString("_status_wait_favorite_", comment: "")
        case global.metadataStatusWaitCopy:
            cell.statusImageView?.image = utility.loadImage(named: "c.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.info?.text = NSLocalizedString("_status_wait_copy_", comment: "")
        case global.metadataStatusWaitMove:
            cell.statusImageView?.image = utility.loadImage(named: "m.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.info?.text = NSLocalizedString("_status_wait_move_", comment: "")
        case global.metadataStatusWaitRename:
            cell.statusImageView?.image = utility.loadImage(named: "a.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.info?.text = NSLocalizedString("_status_wait_rename_", comment: "")
        case global.metadataStatusWaitDownload:
            cell.statusImageView?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
        case global.metadataStatusDownloading:
            cell.statusImageView?.image = utility.loadImage(named: "arrowshape.down.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        case global.metadataStatusDownloadError, global.metadataStatusUploadError:
            cell.statusImageView?.image = utility.loadImage(named: "exclamationmark.circle", colors: NCBrandColor.shared.iconImageMultiColors)
        default:
            break
        }

        // AVATAR
        if !metadata.ownerId.isEmpty, metadata.ownerId != metadata.userId {
            let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: metadata.ownerId)
            if let image = NCImageCache.shared.getImageCache(key: fileName) {
                cell.avatarImageView?.contentMode = .scaleAspectFill
                cell.avatarImageView?.image = image
            } else {
                self.database.getImageAvatarLoaded(fileName: fileName) { image, tblAvatar in
                    if let image {
                        cell.avatarImageView?.contentMode = .scaleAspectFill
                        cell.avatarImageView?.image = image
                        NCImageCache.shared.addImageCache(image: image, key: fileName)
                    } else {
                        cell.avatarImageView?.contentMode = .scaleAspectFill
                        cell.avatarImageView?.image = self.utility.loadUserImage(for: metadata.ownerId, displayName: metadata.ownerDisplayName, urlBase: metadata.urlBase)
                    }

                    if !(tblAvatar?.loaded ?? false),
                       self.networking.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                        self.networking.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: metadata.ownerId, fileName: fileName, account: metadata.account, view: self.collectionView))
                    }
                }
            }
        }

        // URL
        if metadata.classFile == NKTypeClassFile.url.rawValue {
            cell.localImageView?.image = nil
            cell.hideButtonShare(true)
            cell.hideButtonMore(true)
        }

        // Separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 || isSearchingMode {
            cell.separatorView?.isHidden = true
        } else {
            cell.separatorView?.isHidden = false
        }

        // Edit mode
        if fileSelect.contains(metadata.ocId) {
            cell.selected(true, isEditMode: isEditMode)
            a11yValues.append(NSLocalizedString("_selected_", comment: ""))
        } else {
            cell.selected(false, isEditMode: isEditMode)
        }

        // Accessibility
        cell.setAccessibility(label: metadata.fileNameView + ", " + (cell.info?.text ?? "") + (cell.subInfo?.text ?? ""), value: a11yValues.joined(separator: ", "))

        // Color string find in search
        cell.title?.textColor = NCBrandColor.shared.textColor
        cell.title?.font = .systemFont(ofSize: 15)

        if isSearchingMode,
           let searchResultStore,
           let title = cell.title?.text {
            let longestWordRange = (title.lowercased() as NSString).range(of: searchResultStore)
            let attributedString = NSMutableAttributedString(string: title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15)])
            attributedString.setAttributes([NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 15), NSAttributedString.Key.foregroundColor: UIColor.systemBlue], range: longestWordRange)
            cell.title?.attributedText = attributedString
        }

        // TAGS
        cell.setTags(tags: Array(metadata.tags))

        // SearchingMode - TAG Separator Hidden
        if isSearchingMode {
            cell.tagSeparator?.isHidden = true
        }

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
            cell.title?.font = UIFont.systemFont(ofSize: 15)

            if width < 120 {
                cell.hideImageFavorite(true)
                cell.hideImageLocal(true)
                cell.title?.font = UIFont.systemFont(ofSize: 10)
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

        // Obligatory here, at the end !!
        cell.metadata = metadata

        return cell
    }
}
