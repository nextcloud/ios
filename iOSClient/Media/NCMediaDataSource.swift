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
                    self.collectionViewReloadData()
                }
            }
        } else {
            await MainActor.run {
                self.dataSource.clearTinyMetadatas()
                self.collectionViewReloadData()
            }
        }
    }

    @MainActor
    func collectionViewReloadData() {
        collectionView.reloadData()
        setElements()
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

        guard shouldContinue,
              let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", session.account)) else {
            return
        }

        var firstDateNew = Date.distantFuture
        var lastDateNew = Date.distantPast
        var firstDate: Date?
        var lastDate: Date?
        var visibleCells: [NCMediaCell] = []

        await MainActor.run {
            if self.dataSource.tinyMetadatas.isEmpty {
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

                if lastCellDate == self.dataSource.tinyMetadatas.last?.date {
                    lastDateNew = .distantPast
                } else {
                    lastDateNew = Calendar.current.date(byAdding: .second, value: -1, to: lastCellDate ?? .distantPast) ?? .distantPast
                }
            }
        }

        // SEARCH NEW MEDIA
        if firstDateNew == .distantFuture || lastDateNew == .distantPast {
            await self.searchNetworkNewMedia(firstDate: firstDateNew,
                                             lastDate: lastDateNew,
                                             mediaPath: tblAccount.mediaPath) {
                Task {
                    await self.debouncerLoadDataSource.call {
                        await self.loadDataSource()
                    }
                }
            }
        }

        // SEARCH MEDIA
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
            if firstDate == .distantFuture, lastDate == .distantPast, files.isEmpty {
                Task { @MainActor in
                    self.dataSource.clearTinyMetadatas()
                    self.collectionViewReloadData()
                }
            } else {
                Task.detached {
                    if let firstDate = files.first?.date as? NSDate,
                       let lastDate = files.last?.date as? NSDate {
                        await self.updateMedia(files: files, firstDate: firstDate, lastDate: lastDate, mediaPath: mediaPath) {
                            update()
                        }
                    }
                }
            }
        } finish: { }
    }

    internal func verifyNetworkMedia(firstDate: Date?,
                                     lastDate: Date?,
                                     mediaPath: String,
                                     update: @escaping () -> Void,
                                     finish: @escaping () -> Void) async {
        guard let firstDate,
              let lastDate else {
            finish()
            return
        }

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
                Task.detached {
                    if let firstDate = files.first?.date as? NSDate,
                       let lastDate = files.last?.date as? NSDate {
                        await self.updateMedia(files: files, firstDate: firstDate, lastDate: lastDate, mediaPath: mediaPath) {
                            update()
                        }
                    }
                }
            } finish: {
                finish()
            }
    }

    private func updateMedia(files: [NKFile],
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
        let results = await self.database.syncPlaceholderMetadatasAsync(files: files, metadatas: metadatas)

        // DELETE
        var ocIdsToDelete: [String] = []
        for metadata in results.deleted {
            let existsResult = await self.networking.fileExists(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account)
            if existsResult.errorCode == 404 {
                ocIdsToDelete.append(metadata.ocId)
            }
        }
        await self.database.deleteMetadatasAsync(ocIds: ocIdsToDelete)
        if ocIdsToDelete.count > 0, results.inserted > 0, results.updated > 0 {
            update()
        }
    }
}

// MARK: -

@MainActor
public class NCMediaDataSource: NSObject {
    public class TinyMetadata: NSObject {
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
    private(set) var tinyMetadatas: [TinyMetadata] = []

    override init() { super.init() }

    init(metadatas: [tableMetadata]) {
        super.init()

        self.tinyMetadatas = metadatas.map {
            getTinyMetadataFromMetadata($0)
        }
    }

    private func getTinyMetadataFromMetadata(_ metadata: tableMetadata) -> TinyMetadata {
        let date = metadata.date as Date
        return TinyMetadata(date: date,
                            etag: metadata.etag,
                            imageSize: CGSize(width: metadata.width, height: metadata.height),
                            isImage: metadata.classFile == NKTypeClassFile.image.rawValue,
                            isLivePhoto: !metadata.livePhotoFile.isEmpty,
                            isVideo: metadata.classFile == NKTypeClassFile.video.rawValue,
                            ocId: metadata.ocId)
    }

    // MARK: -

    func clearTinyMetadatas() {
        self.tinyMetadatas.removeAll()
    }

    func isEmpty() -> Bool {
        return self.tinyMetadatas.isEmpty
    }

    func indexPath(forOcId ocId: String) -> IndexPath? {
        guard let index = self.tinyMetadatas.firstIndex(where: { $0.ocId == ocId }) else {
            return nil
        }

        return IndexPath(item: index, section: 0)
    }

    func getTinyMetadata(indexPath: IndexPath) -> TinyMetadata? {
        if indexPath.row < self.tinyMetadatas.count {
            return self.tinyMetadatas[indexPath.row]
        }

        return nil
    }

    func getTinyMetadatas(indexPaths: [IndexPath]) -> [TinyMetadata] {
        var metadatas: [TinyMetadata] = []
        for indexPath in indexPaths {
            if indexPath.row < self.tinyMetadatas.count {
                metadatas.append(self.tinyMetadatas[indexPath.row])
            }
        }

        return metadatas
    }

    func removeTinyMetadata(_ ocId: [String]) {
        self.tinyMetadatas.removeAll { item in
            ocId.contains(item.ocId)
        }
    }
}
