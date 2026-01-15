// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
        self.autoUploadFileName = self.database.getAccountAutoUploadFileName(account: session.account)
        self.autoUploadDirectory = self.database.getAccountAutoUploadDirectory(account: session.account, urlBase: session.urlBase, userId: session.userId)
        // get layout for view
        self.layoutForView = self.database.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl)
        // is a Directory E2EE
        if isSearchingMode {
            self.isDirectoryE2EE = false
        } else {
            self.isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, urlBase: session.urlBase, userId: session.userId, account: session.account)
        }
        return self.dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else {
                return
            }

            for case let operation as NCCollectionViewDownloadThumbnail in self.networking.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId {
                operation.cancel()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else {
            return
        }
        let existsImagePreview = self.utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase)
        let ext = self.global.getSizeExtension(column: self.numberOfColumns)

        if metadata.hasPreview,
           !existsImagePreview,
           self.networking.downloadThumbnailQueue.operations.filter({ ($0 as? NCMediaDownloadThumbnail)?.metadata.ocId == metadata.ocId }).isEmpty {
            self.networking.downloadThumbnailQueue.addOperation(NCCollectionViewDownloadThumbnail(metadata: metadata, collectionView: collectionView, ext: ext))
        }

    }

    private func photoCell(cell: NCPhotoCell, indexPath: IndexPath, metadata: tableMetadata, ext: String) -> NCPhotoCell {
        let width = UIScreen.main.bounds.width / CGFloat(self.numberOfColumns)

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

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: NCCellProtocol & UICollectionViewCell
        var isShare = false
        var isMounted = false
        var a11yValues: [String] = []
        let metadata = self.dataSource.getMetadata(indexPath: indexPath) ?? tableMetadata()
        let existsImagePreview = utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase)
        let ext = global.getSizeExtension(column: self.numberOfColumns)

        defer {
            let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
            if !metadata.isSharable() || (!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty) {
                cell.hideButtonShare(true)
            }
        }

        // E2EE create preview
        if self.isDirectoryE2EE,
           metadata.isImageOrVideo,
           !utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase) {
            utility.createImageFileFrom(metadata: metadata)
        }

        // LAYOUT PHOTO
        if isLayoutPhoto {
            if metadata.isImageOrVideo {
                let photoCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? NCPhotoCell)!
                photoCell.delegate = self
                cell = photoCell
                return self.photoCell(cell: photoCell, indexPath: indexPath, metadata: metadata, ext: ext)
            } else {
                let gridCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell)!
                gridCell.delegate = self
                cell = gridCell
            }
        } else if isLayoutGrid {
            // LAYOUT GRID
            let gridCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell)!
            gridCell.delegate = self
            cell = gridCell
        } else {
            // LAYOUT LIST
            let listCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell)!
            listCell.delegate = self
            cell = listCell
        }

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
                                    self.networking.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: ownerId, fileName: fileName, account: metadata.account, view: collectionView, isPreviewImageView: true))
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
                        self.networking.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: metadata.ownerId, fileName: fileName, account: metadata.account, view: collectionView))
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

        if isSearchingMode, let literalSearch = self.literalSearch, let title = cell.title?.text {
            let longestWordRange = (title.lowercased() as NSString).range(of: literalSearch)
            let attributedString = NSMutableAttributedString(string: title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15)])
            attributedString.setAttributes([NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 15), NSAttributedString.Key.foregroundColor: UIColor.systemBlue], range: longestWordRange)
            cell.title?.attributedText = attributedString
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

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        func setContent(header: UICollectionReusableView, indexPath: IndexPath) {
            let (heightHeaderRichWorkspace, heightHeaderRecommendations, heightHeaderSection) = getHeaderHeight(section: indexPath.section)

            if let header = header as? NCSectionFirstHeader {
                let recommendations = self.database.getRecommendedFiles(account: self.session.account)
                var sectionText = NSLocalizedString("_all_files_", comment: "")

                if NCPreferences().getPersonalFilesOnly(account: session.account) {
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
                                  sceneItentifier: self.sceneIdentifier,
                                  delegate: self)

            } else if let header = header as? NCSectionFirstHeaderEmptyData {
                var emptyImage: UIImage?
                var emptyTitle: String?

                if isSearchingMode {
                    emptyImage = utility.loadImage(named: "magnifyingglass", colors: [NCBrandColor.shared.getElement(account: session.account)])
                    if self.searchDataSourceTask?.state == .running {
                        emptyTitle = NSLocalizedString("_search_in_progress_", comment: "")
                    } else {
                        emptyTitle = NSLocalizedString("_search_no_record_found_", comment: "")
                    }
                    emptyDescription = NSLocalizedString("_search_instruction_", comment: "")
                } else if self.searchDataSourceTask?.state == .running || !self.dataSource.getGetServerData() {
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
                    } else if let metadataFolder, !metadataFolder.isCreatable {
                        emptyImage = imageCache.getFolder(account: session.account)
                        emptyTitle = NSLocalizedString("_files_no_files_", comment: "")
                        emptyDescription = NSLocalizedString("_no_file_no_permission_to_create_", comment: "")
                    } else {
                        emptyImage = imageCache.getFolder(account: session.account)
                        emptyTitle = NSLocalizedString("_files_no_files_", comment: "")
                        emptyDescription = NSLocalizedString("_no_file_pull_down_", comment: "")
                    }
                }

                header.setContent(emptyImage: emptyImage,
                                  emptyTitle: emptyTitle,
                                  emptyDescription: emptyDescription)

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
            footer.buttonIsHidden(true)
            footer.hideActivityIndicatorSection()

            if isSearchingMode {
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
            } else if isEditMode {
                // let itemsSelected = self.fileSelect.count
                // let items = self.dataSource.numberOfItemsInSection(section)
                // footer.setTitleLabel("\(itemsSelected) \(NSLocalizedString("_of_", comment: "")) \(items) \(NSLocalizedString("_selected_", comment: ""))")
                footer.setTitleLabel("")
            } else {
                if sections == 1 || section == sections - 1 {
                    let info = self.dataSource.getFooterInformation()
                    footer.setTitleLabel(directories: info.directories, files: info.files, size: info.size)
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

    /// Caches preview images asynchronously for the provided metadata entries.
    /// - Parameters:
    ///   - metadatas: The list of metadata entries to cache.
    ///   - priority: The task priority to use (default is `.utility`).
    func cachingAsync(metadatas: [tableMetadata], priority: TaskPriority = .utility) {
        Task.detached(priority: priority) {
            for (cost, metadata) in metadatas.enumerated() {
                // Skip if not an image or video
                guard metadata.isImageOrVideo else { continue }
                // Check if image is already cached
                let alreadyCached = NCImageCache.shared.getImageCache(ocId: metadata.ocId,
                                                                      etag: metadata.etag,
                                                                      ext: self.global.previewExt256) != nil
                guard !alreadyCached else {
                    continue
                }

                // caching preview
                //
                if let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: self.global.previewExt256, userId: metadata.userId, urlBase: metadata.urlBase) {
                    NCImageCache.shared.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: self.global.previewExt256, cost: cost)
                }
            }
        }
    }

    func removeImageCache(metadatas: [tableMetadata]) {
        DispatchQueue.global().async {
            for metadata in metadatas {
                NCImageCache.shared.removeImageCache(ocIdPlusEtag: metadata.ocId + metadata.etag)
            }
        }
    }
}
