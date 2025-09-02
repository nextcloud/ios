// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

extension NCMedia {
    func loadDataSource() async {
        guard let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", session.account)) else {
            return
        }
        let mediaPredicate = self.imageCache.getMediaPredicateAsync(filterLivePhotoFile: true,
                                                                    session: session,
                                                                    mediaPath: tblAccount.mediaPath,
                                                                    showOnlyImages: self.showOnlyImages,
                                                                    showOnlyVideos: self.showOnlyVideos)
        if let metadatas = await self.database.getMetadatasAsync(predicate: mediaPredicate, sortedByKeyPath: "datePhotosOriginal", ascending: false) {
            await MainActor.run {
                self.dataSource = NCMediaDataSource(metadatas: metadatas)
            }
        } else {
            self.dataSource.clearMetadatas()
        }
        self.collectionViewReloadData()
    }

    @MainActor
    func collectionViewReloadData() {
        self.collectionView.reloadData()
        self.setTitleDate()
    }

    // MARK: - Search media

    func searchMediaUI(_ distant: Bool = false) async {
        let shouldContinue = await MainActor.run { () -> Bool in
            guard self.isViewActived,
                    !self.searchMediaInProgress,
                    !self.isPinchGestureActive,
                    !self.showOnlyImages,
                    !self.showOnlyVideos,
                    !self.isEditMode,
                    self.networking.downloadThumbnailQueue.operationCount == 0 else {
                return false
            }
            self.searchMediaInProgress = true
            self.activityIndicator.startAnimating()
            return true
        }

        guard shouldContinue,
              let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", session.account)) else {
            await MainActor.run {
                self.activityIndicator.stopAnimating()
                self.searchMediaInProgress = false
            }
            return
        }

        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        var lessDate = Date.distantFuture
        var greaterDate = Date.distantPast
        var visibleCells: [NCMediaCell] = []

        await MainActor.run {
            if self.dataSource.metadatas.isEmpty {
                self.collectionViewReloadData()
            }
            let sortedIndexPaths = collectionView.indexPathsForVisibleItems.sorted {
                guard let attr1 = collectionView.layoutAttributesForItem(at: $0),
                      let attr2 = collectionView.layoutAttributesForItem(at: $1) else {
                    return false
                }
                return attr1.frame.minY < attr2.frame.minY
            }

            visibleCells = sortedIndexPaths.compactMap { indexPath in
                guard let cell = collectionView.cellForItem(at: indexPath) as? NCMediaCell else {
                    return nil
                }

                // Convert cell frame to collectionView coordinate space
                let cellFrameInCollection = collectionView.convert(cell.frame, from: cell.superview)

                // Check if it intersects with the visible bounds
                if cellFrameInCollection.intersects(collectionView.bounds) {
                    return cell
                } else {
                    return nil
                }
            }

            visibleCells = visibleCells.sorted {
                guard let date1 = $0.datePhotosOriginal, let date2 = $1.datePhotosOriginal else {
                    return false
                }
                return date1 > date2
            }

            if !visibleCells.isEmpty, !distant {
                let firstCellDate = visibleCells.first?.datePhotosOriginal
                let lastCellDate = visibleCells.last?.datePhotosOriginal

                if collectionView.contentOffset.y <= 0 {
                    lessDate = .distantFuture
                } else {
                    lessDate = Calendar.current.date(byAdding: .second, value: 1, to: firstCellDate ?? .distantFuture) ?? .distantFuture
                }

                if lastCellDate == self.dataSource.metadatas.last?.datePhotosOriginal {
                    greaterDate = .distantPast
                } else {
                    greaterDate = Calendar.current.date(byAdding: .second, value: -1, to: lastCellDate ?? .distantPast) ?? .distantPast
                }
            }
        }

        let elementDate: String
        var lessDateAny: Any
        var greaterDateAny: Any

        if capabilities.serverVersionMajor >= self.global.nextcloudVersion31 {
            elementDate = "nc:metadata-photos-original_date_time"
            lessDateAny = Int(lessDate.timeIntervalSince1970)
            greaterDateAny = Int(greaterDate.timeIntervalSince1970)
        } else {
            elementDate = "d:getlastmodified"
            lessDateAny = lessDate
            greaterDateAny = greaterDate
        }

        let limit = await MainActor.run {
            max(self.collectionView.visibleCells.count * 3, 300)
        }

        let options = NKRequestOptions(timeout: 180, taskDescription: self.global.taskDescriptionRetrievesProperties, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let result = await NextcloudKit.shared.searchMediaAsync(path: tblAccount.mediaPath,
                                                                lessDate: lessDateAny,
                                                                greaterDate: greaterDateAny,
                                                                elementDate: elementDate,
                                                                limit: limit,
                                                                account: self.session.account,
                                                                options: options) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                            name: "searchMedia")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        guard result.error == .success, let files = result.files, !self.showOnlyImages, !self.showOnlyVideos else {
            nkLog(error: "Media search failed: \(result.error.errorDescription)")
            await MainActor.run {
                self.searchMediaInProgress = false
                self.collectionViewReloadData()
                self.activityIndicator.stopAnimating()
            }
            return
        }

        if lessDate == .distantFuture, greaterDate == .distantPast, files.isEmpty {
            await MainActor.run {
                self.dataSource.clearMetadatas()
                self.collectionViewReloadData()
            }
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                return
            }
            let (_, remoteMetadatas) = await self.database.convertFilesToMetadatasAsync(files, mediaSearch: true)
            let mediaPredicate = await self.imageCache.getMediaPredicateAsync(filterLivePhotoFile: false,
                                                                        session: session,
                                                                        mediaPath: tblAccount.mediaPath,
                                                                        showOnlyImages: self.showOnlyImages,
                                                                        showOnlyVideos: self.showOnlyVideos)

            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "datePhotosOriginal >= %@ AND datePhotosOriginal <= %@ AND mediaSearch == true", greaterDate as NSDate, lessDate as NSDate),
                mediaPredicate
            ])
            let localMetadatas = await self.database.getMetadatasAsync(predicate: predicate)

            await MainActor.run {
                self.activityIndicator.stopAnimating()
                self.searchMediaInProgress = false
            }

            if await database.mergeRemoteMetadatasAsync(remoteMetadatas: remoteMetadatas, localMetadatas: localMetadatas) {
                await loadDataSource()
            } else if await self.dataSource.isEmpty() {
                await self.collectionViewReloadData()
            }
        }
    }
}

// MARK: -

@MainActor
public class NCMediaDataSource: NSObject {
    public class Metadata: NSObject {
        let datePhotosOriginal: Date
        let etag: String
        let imageSize: CGSize
        let isImage: Bool
        let isLivePhoto: Bool
        let isVideo: Bool
        let ocId: String

        init(datePhotosOriginal: Date,
             etag: String,
             imageSize: CGSize,
             isImage: Bool,
             isLivePhoto: Bool,
             isVideo: Bool,
             ocId: String) {
            self.datePhotosOriginal = datePhotosOriginal
            self.etag = etag
            self.imageSize = imageSize
            self.isImage = isImage
            self.isLivePhoto = isLivePhoto
            self.isVideo = isVideo
            self.ocId = ocId
        }
    }

    private let utilityFileSystem = NCUtilityFileSystem()
    private let global = NCGlobal.shared
    private(set) var metadatas: [Metadata] = []

    override init() { super.init() }

    init(metadatas: [tableMetadata]) {
        super.init()

        self.metadatas = metadatas.map { getMetadataFromTableMetadata($0) }
    }

    private func insertInMetadatas(metadata: Metadata) {
        for i in 0..<self.metadatas.count {
            if (metadata.datePhotosOriginal as Date) > self.metadatas[i].datePhotosOriginal {
                self.metadatas.insert(metadata, at: i)
                return
            }
        }

        self.metadatas.append(metadata)
    }

    private func getMetadataFromTableMetadata(_ metadata: tableMetadata) -> Metadata {
        return Metadata(datePhotosOriginal: metadata.datePhotosOriginal as Date,
                        etag: metadata.etag,
                        imageSize: CGSize(width: metadata.width, height: metadata.height),
                        isImage: metadata.classFile == NKTypeClassFile.image.rawValue,
                        isLivePhoto: !metadata.livePhotoFile.isEmpty,
                        isVideo: metadata.classFile == NKTypeClassFile.video.rawValue,
                        ocId: metadata.ocId)
    }

    // MARK: -

    func clearMetadatas() {
        metadatas.removeAll()
    }

    func isEmpty() -> Bool {
        return self.metadatas.isEmpty
    }

    func indexPath(forOcId ocId: String) -> IndexPath? {
        guard let index = self.metadatas.firstIndex(where: { $0.ocId == ocId }) else {
            return nil
        }

        return IndexPath(item: index, section: 0)
    }

    func getMetadata(indexPath: IndexPath) -> Metadata? {
        if indexPath.row < self.metadatas.count {
            return self.metadatas[indexPath.row]
        }

        return nil
    }

    func getMetadatas(indexPaths: [IndexPath]) -> [Metadata] {
        var metadatas: [Metadata] = []
        for indexPath in indexPaths {
            if indexPath.row < self.metadatas.count {
                metadatas.append(self.metadatas[indexPath.row])
            }
        }

        return metadatas
    }

    func removeMetadata(_ ocId: [String]) {
        self.metadatas.removeAll { item in
            ocId.contains(item.ocId)
        }
    }
}
