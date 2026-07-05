// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

extension NCMedia {
    func loadDataSource() async {
        guard let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", self.session.account)) else {
            return
        }
        let mediaPredicate = self.imageCache.getMediaPredicate(
            session: self.session,
            mediaPath: tblAccount.mediaPath,
            showOnlyImages: self.showOnlyImages,
            showOnlyVideos: self.showOnlyVideos)

        if let metadatas = await self.database.getMetadatasAsync(predicate: mediaPredicate, sortedByKeyPath: "date", ascending: false) {
            self.database.filterAndNormalizeLivePhotos(from: metadatas) { metadatas in
                Task { @MainActor in
                    self.dataSource = NCMediaDataSource(metadatas: metadatas)
                    self.collectionViewReloadDataKeepingPosition()
                }
            }
        } else {
            await MainActor.run {
                self.dataSource.clearCompactMetadatas()
                self.collectionViewReloadData()
            }
        }
    }

    @MainActor
    func collectionViewReloadData() {
        collectionView.reloadData()
        setElements()
    }

    // MARK: - Keeping position

    @MainActor
    private func captureScrollAnchor() -> CollectionViewScrollAnchor? {
        let visibleRect = CGRect(
            x: collectionView.contentOffset.x + collectionView.adjustedContentInset.left,
            y: collectionView.contentOffset.y + collectionView.adjustedContentInset.top,
            width: collectionView.bounds.width - collectionView.adjustedContentInset.left - collectionView.adjustedContentInset.right,
            height: collectionView.bounds.height - collectionView.adjustedContentInset.top - collectionView.adjustedContentInset.bottom
        )

        guard let attributes = collectionView.collectionViewLayout
            .layoutAttributesForElements(in: visibleRect)?
            .filter({ $0.representedElementCategory == .cell })
            .sorted(by: {
                if abs($0.frame.minY - $1.frame.minY) > 1 {
                    return $0.frame.minY < $1.frame.minY
                }

                return $0.frame.minX < $1.frame.minX
            })
            .first,
              let metadata = dataSource.getCompactMetadata(indexPath: attributes.indexPath) else {
            return nil
        }

        return CollectionViewScrollAnchor(
            ocId: metadata.ocId,
            deltaX: visibleRect.minX - attributes.frame.minX,
            deltaY: visibleRect.minY - attributes.frame.minY
        )
    }

    @MainActor
    private func restoreScrollAnchor(_ anchor: CollectionViewScrollAnchor?) {
        guard let anchor,
              let indexPath = dataSource.indexPath(forOcId: anchor.ocId) else {
            return
        }

        guard let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath) else {
            return
        }

        let targetOffset = CGPoint(
            x: attributes.frame.minX + anchor.deltaX - collectionView.adjustedContentInset.left,
            y: attributes.frame.minY + anchor.deltaY - collectionView.adjustedContentInset.top
        )

        let minimumOffset = CGPoint(
            x: -collectionView.adjustedContentInset.left,
            y: -collectionView.adjustedContentInset.top
        )

        let maximumOffset = CGPoint(
            x: max(
                minimumOffset.x,
                collectionView.contentSize.width
                    - collectionView.bounds.width
                    + collectionView.adjustedContentInset.right
            ),
            y: max(
                minimumOffset.y,
                collectionView.contentSize.height
                    - collectionView.bounds.height
                    + collectionView.adjustedContentInset.bottom
            )
        )

        collectionView.setContentOffset(
            CGPoint(
                x: min(max(targetOffset.x, minimumOffset.x), maximumOffset.x),
                y: min(max(targetOffset.y, minimumOffset.y), maximumOffset.y)
            ),
            animated: false
        )
    }

    @MainActor
    func collectionViewReloadDataKeepingPosition() {
        let anchor = captureScrollAnchor()

        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        DispatchQueue.main.async {
            self.collectionView.layoutIfNeeded()
            self.restoreScrollAnchor(anchor)
            self.setElements()
        }
    }

    // MARK: - Search media

    func searchMediaUI(_ distant: Bool = false) async {
        let shouldContinue = await MainActor.run { () -> Bool in
            guard self.isViewActived,
                    !self.searchMediaInProgress,
                    !self.isPinchGestureActive,
                    !self.showOnlyImages,
                    !self.showOnlyVideos,
                    !self.isEditMode else {
                return false
            }
            self.searchMediaInProgress = true
            self.activityIndicator.startAnimating()
            return true
        }

        guard shouldContinue else {
            return
        }

        guard let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", session.account)) else {
            await MainActor.run {
                self.activityIndicator.stopAnimating()
                self.searchMediaInProgress = false
            }
            return
        }

        var firstDateNew = Date.distantFuture
        var lastDateNew = Date.distantPast
        var firstDate: Date?
        var lastDate: Date?
        var visibleCells: [NCMediaCell] = []

        await MainActor.run {
            if self.dataSource.compactMetadatas.isEmpty {
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
                guard let date1 = $0.date, let date2 = $1.date else {
                    return false
                }
                return date1 > date2
            }

            firstDate = visibleCells.first?.date
            lastDate = visibleCells.last?.date

            if !visibleCells.isEmpty, !distant {
                let firstCellDate = visibleCells.first?.date
                let lastCellDate = visibleCells.last?.date

                if collectionView.contentOffset.y <= 0 {
                    firstDateNew = .distantFuture
                } else {
                    firstDateNew = Calendar.current.date(byAdding: .second, value: 1, to: firstCellDate ?? .distantFuture) ?? .distantFuture
                }

                if lastCellDate == self.dataSource.compactMetadatas.last?.date {
                    lastDateNew = .distantPast
                } else {
                    lastDateNew = Calendar.current.date(byAdding: .second, value: -1, to: lastCellDate ?? .distantPast) ?? .distantPast
                }
            }
        }

        // SEARCH NEW MEDIA
        //
        if firstDateNew == .distantFuture || lastDateNew == .distantPast {
            await self.searchNetworkNewMedia(firstDate: firstDateNew,
                                             lastDate: lastDateNew,
                                             mediaPath: tblAccount.mediaPath) {
                Task {
                    await self.loadDataSource()
                }
            }
        }

        guard let firstDate, let lastDate else {
            Task { @MainActor in
                self.activityIndicator.stopAnimating()
                self.searchMediaInProgress = false
            }
            return
        }

        await self.verifyNetworkMedia(firstDate: firstDate,
                                      lastDate: lastDate,
                                      mediaPath: tblAccount.mediaPath) {
            Task {
                await self.debouncerLoadDataSource.call {
                    await self.loadDataSource()
                }
            }
        } finish: {
            Task { @MainActor in
                self.activityIndicator.stopAnimating()
                self.searchMediaInProgress = false
            }
        }
    }

    internal func searchNetworkNewMedia(firstDate: Date,
                                        lastDate: Date,
                                        mediaPath: String,
                                        update: @escaping () -> Void) async {
        let limit = await MainActor.run {
            max(self.collectionView.visibleCells.count * 3, 300)
        }

        await self.searchVerifyNetworkMedia(path: mediaPath,
                                            firstDate: firstDate,
                                            lastDate: lastDate,
                                            account: self.session.account,
                                            paginate: false,
                                            limit: limit) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: self.session.account,
                    name: "searchMedia")
                await NCNetworking.shared.networkingTasks.track(
                    identifier: identifier,
                    task: task)
            }
        } update: { files in
            if firstDate == .distantFuture,
               lastDate == .distantPast,
               files.isEmpty {
                await MainActor.run {
                    self.dataSource.clearCompactMetadatas()
                    self.collectionViewReloadData()
                }
            } else {
                await self.updateMediaMetadatas(files: files,
                                                firstDate: firstDate as NSDate,
                                                lastDate: lastDate as NSDate,
                                                mediaPath: mediaPath) {
                    update()
                }
            }
        } finish: { }
    }

    internal func verifyNetworkMedia(firstDate: Date,
                                     lastDate: Date,
                                     mediaPath: String,
                                     update: @escaping () -> Void,
                                     finish: @escaping () -> Void) async {
        await self.searchVerifyNetworkMedia(
            path: mediaPath,
            firstDate: firstDate,
            lastDate: lastDate,
            account: self.session.account,
            paginate: true,
            limit: 100000) { task in
                Task.detached {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: self.session.account,
                        name: "verifyNetworkMedia"
                    )
                    await NCNetworking.shared.networkingTasks.track(
                        identifier: identifier,
                        task: task)
                }
            } update: { files in
                if let firstDate = files.first?.date as? NSDate,
                   let lastDate = files.last?.date as? NSDate {
                    await self.updateMediaMetadatas(files: files,
                                                    firstDate: firstDate,
                                                    lastDate: lastDate,
                                                    mediaPath: mediaPath) {
                        update()
                    }
                }
            } finish: {
                finish()
            }
    }

    private func updateMediaMetadatas(files: [NKFile],
                                      firstDate: NSDate,
                                      lastDate: NSDate,
                                      mediaPath: String,
                                      update: @escaping () -> Void) async {
        // DB
        let mediaPredicate = self.imageCache.getMediaPredicate(
            session: self.session,
            mediaPath: mediaPath,
            showOnlyImages: self.showOnlyImages,
            showOnlyVideos: self.showOnlyVideos)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "date >= %@ AND date <= %@", lastDate, firstDate), mediaPredicate
        ])
        let metadatas = await self.database.getMetadatasAsync(
            predicate: predicate,
            sortedByKeyPath: "date",
            ascending: false) ?? []
        let results = await self.database.syncPlaceholderMetadatasAsync(files: files,
                                                                        metadatas: metadatas)

        // DELETE
        let deletedMetadatas = results.deleted

        // Confirm every deletion candidate with WebDAV before removing it from
        // the local database, regardless of whether the search is paginated.
        let maximumConcurrentChecks = max(1, NCBrandOptions.shared.httpMaximumConnectionsPerHost)

        if results.inserted > 0 || results.updated > 0 {
            update()
        }

        for batchStart in stride(from: 0, to: deletedMetadatas.count, by: maximumConcurrentChecks) {
            let batchEnd = min(batchStart + maximumConcurrentChecks, deletedMetadatas.count)
            let batch = deletedMetadatas[batchStart..<batchEnd]

            let ocIdsToDelete = await withTaskGroup(of: String?.self, returning: Set<String>.self) { group in
                for metadata in batch {
                    group.addTask {
                        let existsResult = await self.networking.fileExists(
                            serverUrlFileName: metadata.serverUrlFileName,
                            account: metadata.account
                        )
                        return existsResult.errorCode == 404 ? metadata.ocId : nil
                    }
                }

                var ocIds = Set<String>()
                for await ocId in group {
                    if let ocId {
                        ocIds.insert(ocId)
                    }
                }
                return ocIds
            }

            guard !ocIdsToDelete.isEmpty else {
                continue
            }

            await self.database.deleteMetadatasAsync(ocIds: Array(ocIdsToDelete))
            update()
        }
    }
}

// MARK: -

@MainActor
public class NCMediaDataSource: NSObject {
    public class NCCompactMetadata: NSObject {
        let date: Date
        let etag: String
        let imageSize: CGSize
        let isImage: Bool
        let isLivePhoto: Bool
        let isVideo: Bool
        let ocId: String

        init(date: Date,
             etag: String,
             imageSize: CGSize,
             isImage: Bool,
             isLivePhoto: Bool,
             isVideo: Bool,
             ocId: String) {
            self.date = date
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
    private(set) var compactMetadatas: [NCCompactMetadata] = []

    override init() { super.init() }

    init(metadatas: [tableMetadata]) {
        super.init()

        self.compactMetadatas = metadatas.map {
            getCompactMetadataFromMetadata($0)
        }
    }

    private func getCompactMetadataFromMetadata(_ metadata: tableMetadata) -> NCCompactMetadata {
        let date = metadata.date as Date
        return NCCompactMetadata(date: date,
                                 etag: metadata.etag,
                                 imageSize: CGSize(width: metadata.width, height: metadata.height),
                                 isImage: metadata.classFile == NKTypeClassFile.image.rawValue,
                                 isLivePhoto: !metadata.livePhotoFile.isEmpty,
                                 isVideo: metadata.classFile == NKTypeClassFile.video.rawValue,
                                 ocId: metadata.ocId)
    }

    // MARK: -

    func clearCompactMetadatas() {
        self.compactMetadatas.removeAll()
    }

    func isEmpty() -> Bool {
        return self.compactMetadatas.isEmpty
    }

    func indexPath(forOcId ocId: String) -> IndexPath? {
        guard let index = self.compactMetadatas.firstIndex(where: { $0.ocId == ocId }) else {
            return nil
        }

        return IndexPath(item: index, section: 0)
    }

    func getCompactMetadata(indexPath: IndexPath) -> NCCompactMetadata? {
        if indexPath.row < self.compactMetadatas.count {
            return self.compactMetadatas[indexPath.row]
        }

        return nil
    }

    func getCompactMetadatas(indexPaths: [IndexPath]) -> [NCCompactMetadata] {
        var metadatas: [NCCompactMetadata] = []
        for indexPath in indexPaths {
            if indexPath.row < self.compactMetadatas.count {
                metadatas.append(self.compactMetadatas[indexPath.row])
            }
        }

        return metadatas
    }

    func removeCompactMetadata(_ ocId: [String]) {
        self.compactMetadatas.removeAll { item in
            ocId.contains(item.ocId)
        }
    }
}
