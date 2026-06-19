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
        let mediaPredicate = self.imageCache.getMediaPredicate(session: self.session,
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
                self.dataSource.clearMetadatas()
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

        var lessDate = Date.distantFuture
        var greaterDate = Date.distantPast
        var firstDate: Date?
        var lastDate: Date?
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
                    lessDate = .distantFuture
                } else {
                    lessDate = Calendar.current.date(byAdding: .second, value: 1, to: firstCellDate ?? .distantFuture) ?? .distantFuture
                }

                if lastCellDate == self.dataSource.metadatas.last?.date {
                    greaterDate = .distantPast
                } else {
                    greaterDate = Calendar.current.date(byAdding: .second, value: -1, to: lastCellDate ?? .distantPast) ?? .distantPast
                }
            }
        }

        await self.searchNetworkNewMedia(lessDate: lessDate,
                                         greaterDate: greaterDate,
                                         mediaPath: tblAccount.mediaPath) {
            Task {
                await self.debouncerLoadDataSource.call {
                    await self.loadDataSource()
                }
            }
        }

        await self.searchNetworkMediaPlaceholders(firstDate: firstDate,
                                                  lastDate: lastDate,
                                                  mediaPath: tblAccount.mediaPath) { update in
            if update {
                Task {
                    await self.debouncerLoadDataSource.call {
                        await self.loadDataSource()
                    }
                }
            }
        } finish: {
            Task { @MainActor in
                self.activityIndicator.stopAnimating()
                self.searchMediaInProgress = false
            }
        }
    }

    internal func searchNetworkNewMedia(lessDate: Date,
                                        greaterDate: Date,
                                        mediaPath: String,
                                        update: @escaping () -> Void) async {
        if lessDate != .distantFuture, greaterDate != .distantPast {
            return
        }

        let limit = await MainActor.run {
            max(self.collectionView.visibleCells.count * 3, 300)
        }

        let result = await searchNewMediaAsync(path: mediaPath,
                                               lessDate: lessDate,
                                               greaterDate: greaterDate,
                                               limit: limit,
                                               account: self.session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: self.session.account,
                    name: "searchMedia")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        guard result.error == .success, let files = result.files, !self.showOnlyImages, !self.showOnlyVideos else {
            nkLog(error: "Media search failed: \(result.error.errorDescription)")
            return
        }

        if lessDate == .distantFuture, greaterDate == .distantPast, files.isEmpty {
            await MainActor.run {
                self.dataSource.clearMetadatas()
                self.collectionViewReloadData()
            }
        }

        let (_, metadatas) = await NCManageDatabaseCreateMetadata().convertFilesToMetadatasAsync(files)

        await database.addMetadatasAsync(metadatas)

        update()
    }

    internal func searchNetworkMediaPlaceholders(firstDate: Date?,
                                                 lastDate: Date?,
                                                 mediaPath: String,
                                                 update: @escaping (Bool) -> Void,
                                                 finish: @escaping () -> Void) async {
        guard let firstDate,
              let lastDate else {
            update(false)
            finish()
            return
        }

        await self.searchMediaPlaceholders(
            path: mediaPath,
            firstDate: firstDate,
            lastDate: lastDate,
            account: self.session.account) { task in
                Task.detached {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: self.session.account,
                        name: "searchMediaPlaceholders"
                    )
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            } update: { files in
                Task.detached {
                    if let firstDate = files.first?.date as? NSDate,
                       let lastDate = files.last?.date as? NSDate {
                        let mediaPredicate = await self.imageCache.getMediaPredicate(
                            session: self.session,
                            mediaPath: mediaPath,
                            showOnlyImages: self.showOnlyImages,
                            showOnlyVideos: self.showOnlyVideos)

                        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                            NSPredicate(format: "date >= %@ AND date <= %@", lastDate, firstDate), mediaPredicate
                        ])

                        let metadatas = await self.database.getMetadatasAsync(predicate: predicate,
                                                                              sortedByKeyPath: "date",
                                                                              ascending: false) ?? []

                        let isUpdated = await self.database.syncPlaceholderMetadatasAsync(files: files, metadatas: metadatas)
                        update(isUpdated)
                    }
                }
            } finish: {
                finish()
            }
    }
}

// MARK: -

@MainActor
public class NCMediaDataSource: NSObject {
    public class Metadata: NSObject {
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
    private(set) var metadatas: [Metadata] = []

    override init() { super.init() }

    init(metadatas: [tableMetadata]) {
        super.init()

        self.metadatas = metadatas.map { getMetadataFromTableMetadata($0) }
    }

    private func insertInMetadatas(metadata: Metadata) {
        for i in 0..<self.metadatas.count {
            if (metadata.date) > self.metadatas[i].date {
                self.metadatas.insert(metadata, at: i)
                return
            }
        }

        self.metadatas.append(metadata)
    }

    private func getMetadataFromTableMetadata(_ metadata: tableMetadata) -> Metadata {
        let date = metadata.date as Date
        return Metadata(date: date,
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
