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

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: NCCellProtocol & UICollectionViewCell
        let metadata = self.dataSource.getMetadata(indexPath: indexPath) ?? tableMetadata()

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
                return self.photoCell(cell: photoCell, indexPath: indexPath, metadata: metadata)
            } else {
                let gridCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell)!
                gridCell.delegate = self
                cell = gridCell
                return self.gridCell(cell: gridCell, indexPath: indexPath, metadata: metadata)
            }
        } else if isLayoutGrid {
            // LAYOUT GRID
            let gridCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell)!
            gridCell.delegate = self
            cell = gridCell
            return self.gridCell(cell: gridCell, indexPath: indexPath, metadata: metadata)
        } else {
            // LAYOUT LIST
            let listCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell)!
            listCell.delegate = self
            cell = listCell
            return self.listCell(cell: listCell, indexPath: indexPath, metadata: metadata)
        }
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
                    if self.searchTask?.state == .running {
                        emptyTitle = NSLocalizedString("_search_in_progress_", comment: "")
                    } else {
                        emptyTitle = NSLocalizedString("_search_no_record_found_", comment: "")
                    }
                    emptyDescription = NSLocalizedString("_search_instruction_", comment: "")
                } else if self.searchTask?.state == .running || !self.dataSource.getGetServerData() {
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
            let unifiedSearchInProgress = metadataForSection?.unifiedSearchInProgress ?? false

            footer.delegate = self
            footer.metadataForSection = metadataForSection

            footer.setTitleLabel("")
            footer.setButtonText(NSLocalizedString("_show_more_results_", comment: ""))
            footer.buttonIsHidden(true)
            footer.hideActivityIndicatorSection()

            if isSearchingMode {
                if metadataForSection?.lastSearchResult?.cursor != nil {
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
