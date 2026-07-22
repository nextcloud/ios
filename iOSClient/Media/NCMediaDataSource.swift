// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

extension NCMedia {
    func loadDataSource() async {
        let account = self.session.account

        guard let tblAccount = await self.database.getTableAccountAsync(
            predicate: NSPredicate(format: "account == %@", account)
        ) else {
            return
        }

        guard self.session.account == account else {
            return
        }

        let mediaPredicate = self.imageCache.getMediaPredicate(
            session: self.session,
            mediaPath: tblAccount.mediaPath,
            showOnlyImages: self.showOnlyImages,
            showOnlyVideos: self.showOnlyVideos)

        guard self.session.account == account else {
            return
        }

        if let metadatas = await self.database.getMetadatasAsync(
            predicate: mediaPredicate,
            sortedByKeyPath: "date",
            ascending: false
        ) {
            guard self.session.account == account else {
                return
            }

            self.database.filterAndNormalizeLivePhotos(from: metadatas) { metadatas in
                Task { @MainActor in
                    guard self.isViewActived,
                          self.session.account == account else {
                        return
                    }

                    self.dataSource = NCMediaDataSource(metadatas: metadatas)
                    self.collectionViewReloadDataKeepingPosition()
                }
            }
        } else {
            await MainActor.run {
                guard self.isViewActived,
                      self.session.account == account else {
                    return
                }

                self.dataSource.clearCompactMetadatas()
                self.collectionViewReloadData()
            }
        }
    }

    @MainActor
    func collectionViewReloadData() {
        collectionView.reloadData()
        setTitleDate()
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
            guard self.isViewActived else {
                return
            }

            self.collectionView.layoutIfNeeded()
            self.restoreScrollAnchor(anchor)
            self.setTitleDate()
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
            return true
        }

        guard shouldContinue else {
            return
        }
        let account = self.session.account

        guard let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", account)) else {
            await MainActor.run {
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

        guard self.session.account == account else {
            await MainActor.run {
                self.searchMediaInProgress = false
            }
            return
        }

        // SEARCH NEW MEDIA
        //
        if firstDateNew == .distantFuture || lastDateNew == .distantPast {
            await self.searchNetworkNewMedia(firstDate: firstDateNew,
                                             lastDate: lastDateNew,
                                             mediaPath: tblAccount.mediaPath,
                                             account: account) {
                Task {
                    guard self.session.account == account else {
                        return
                    }
                    await self.loadDataSource()
                }
            }
        }
        guard self.session.account == account else {
            await MainActor.run {
                self.searchMediaInProgress = false
            }
            return
        }

        guard let firstDate, let lastDate else {
            Task { @MainActor in
                self.searchMediaInProgress = false
            }
            return
        }

        // VERIFY MEDIA
        //
        await self.verifyNetworkMedia(firstDate: firstDate,
                                      lastDate: lastDate,
                                      mediaPath: tblAccount.mediaPath,
                                      account: account) {
            Task {
                guard self.session.account == account else {
                    return
                }

                await self.debouncerLoadDataSource.call {
                    guard self.session.account == account else {
                        return
                    }
                    await self.loadDataSource()
                }
            }
        } finish: {
            Task { @MainActor in
                self.searchMediaInProgress = false
            }
        }
    }

    /// Searches the server for new media within the given date range,
    /// syncs the returned files with the local database, and refreshes the UI.
    internal func searchNetworkNewMedia(firstDate: Date,
                                        lastDate: Date,
                                        mediaPath: String,
                                        account: String,
                                        update: @escaping () -> Void) async {
        let limit = await MainActor.run {
            max(self.collectionView.visibleCells.count * 3, 300)
        }

        await NCMediaNetwork().searchMediaPage(
            path: mediaPath,
            firstDate: firstDate,
            lastDate: lastDate,
            account: account,
            paginate: false,
            limit: limit) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: account,
                        name: "searchMedia")
                    await NCNetworking.shared.networkingTasks.track(
                        identifier: identifier,
                        task: task)
                }
            } update: { files in
                guard self.session.account == account else {
                    return
                }
                await self.updateMediaMetadatas(files: files,
                                                firstDate: firstDate as NSDate,
                                                lastDate: lastDate as NSDate,
                                                mediaPath: mediaPath,
                                                account: account) {
                    guard self.session.account == account else {
                        return
                    }
                    if self.isViewActived {
                        update()
                    }
                }
            } finish: { }
    }

    /// Verifies the media currently visible in the collection against the server,
    /// syncs each result page with the local database, and refreshes the UI.
    internal func verifyNetworkMedia(firstDate: Date,
                                     lastDate: Date,
                                     mediaPath: String,
                                     account: String,
                                     update: @escaping () -> Void,
                                     finish: @escaping () -> Void) async {
        await NCMediaNetwork().searchMediaPage(
            path: mediaPath,
            firstDate: firstDate,
            lastDate: lastDate,
            account: account,
            paginate: true,
            limit: 1000000) { task in
                Task.detached {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: account,
                        name: "verifyNetworkMedia"
                    )
                    await NCNetworking.shared.networkingTasks.track(
                        identifier: identifier,
                        task: task)
                }
            } update: { files in
                guard self.session.account == account else {
                    return
                }
                let pageFirstDate = (files.first?.date as? NSDate) ?? firstDate as NSDate
                let pageLastDate = (files.last?.date as? NSDate) ?? lastDate as NSDate

                await self.updateMediaMetadatas(files: files,
                                                firstDate: pageFirstDate,
                                                lastDate: pageLastDate,
                                                mediaPath: mediaPath,
                                                account: account) {
                    guard self.session.account == account else {
                        return
                    }
                    if self.isViewActived {
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
                                      account: String,
                                      update: @escaping () -> Void) async {
        guard self.session.account == account else {
            return
        }
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
        guard self.session.account == account else {
            return
        }
        let results = await self.database.syncPlaceholderMetadatasAsync(files: files,
                                                                        metadatas: metadatas)
        guard self.session.account == account else {
            return
        }
        // DELETE
        let deletedMetadatas = results.deleted

        // Confirm every deletion candidate with WebDAV before removing it from
        // the local database, regardless of whether the search is paginated.
        let maximumConcurrentChecks = max(1, NCBrandOptions.shared.httpMaximumConnectionsPerHost)

        if results.inserted > 0 || results.updated > 0,
           self.isViewActived,
           self.session.account == account {
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

            guard self.session.account == account else {
                return
            }
            await self.database.deleteMetadatasAsync(ocIds: Array(ocIdsToDelete))
            if self.isViewActived,
               self.session.account == account {
                update()
            }
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

    public struct NCMediaSection {
        let yearMonth: NCYearMonth
        var compactMetadatas: [NCCompactMetadata]
    }

    private let utilityFileSystem = NCUtilityFileSystem()
    private let global = NCGlobal.shared
    private(set) var compactMetadatas: [NCCompactMetadata] = []
    private(set) var sections: [NCMediaSection] = []

    var availableYearMonths: [NCYearMonth] {
        sections.map(\.yearMonth)
    }

    override init() { super.init() }

    init(metadatas: [tableMetadata]) {
        super.init()

        self.compactMetadatas = metadatas.map {
            getCompactMetadataFromMetadata($0)
        }

        self.sections = makeSections(from: compactMetadatas)
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
        compactMetadatas.removeAll()
        sections.removeAll()
    }

    func isEmpty() -> Bool {
        return self.compactMetadatas.isEmpty
    }

    var numberOfSections: Int {
        sections.count
    }

    func numberOfItems(in section: Int) -> Int {
        guard sections.indices.contains(section) else {
            return 0
        }

        return sections[section].compactMetadatas.count
    }

    func yearMonth(for section: Int) -> NCYearMonth? {
        guard sections.indices.contains(section) else {
            return nil
        }

        return sections[section].yearMonth
    }

    var allOcIds: [String] {
        compactMetadatas.map(\.ocId)
    }

    func indexPath(forOcId ocId: String) -> IndexPath? {
        for (sectionIndex, section) in sections.enumerated() {
            guard let itemIndex = section.compactMetadatas.firstIndex(where: {
                $0.ocId == ocId
            }) else {
                continue
            }

            return IndexPath(
                item: itemIndex,
                section: sectionIndex
            )
        }

        return nil
    }

    func getCompactMetadata(indexPath: IndexPath) -> NCCompactMetadata? {
        guard sections.indices.contains(indexPath.section) else {
            return nil
        }

        let metadatas = sections[indexPath.section].compactMetadatas

        guard metadatas.indices.contains(indexPath.item) else {
            return nil
        }

        return metadatas[indexPath.item]
    }

    func getCompactMetadatas(indexPaths: [IndexPath]) -> [NCCompactMetadata] {
        indexPaths.compactMap {
            getCompactMetadata(indexPath: $0)
        }
    }

    func removeCompactMetadata(_ ocIds: [String]) {
        let ocIds = Set(ocIds)

        compactMetadatas.removeAll { metadata in
            ocIds.contains(metadata.ocId)
        }

        sections = makeSections(from: compactMetadatas)
    }

    func firstIndexPath(year: Int, month: Int) -> IndexPath? {
        let yearMonth = NCYearMonth(
            year: year,
            month: month
        )

        guard let sectionIndex = sections.firstIndex(where: {
            $0.yearMonth == yearMonth
        }) else {
            return nil
        }

        guard !sections[sectionIndex].compactMetadatas.isEmpty else {
            return nil
        }

        return IndexPath(
            item: 0,
            section: sectionIndex
        )
    }

    private func makeSections(
        from metadatas: [NCCompactMetadata]
    ) -> [NCMediaSection] {
        var sections: [NCMediaSection] = []

        for metadata in metadatas {
            guard let yearMonth = NCYearMonth(date: metadata.date) else {
                continue
            }

            if sections.last?.yearMonth == yearMonth {
                sections[sections.count - 1]
                    .compactMetadatas
                    .append(metadata)
            } else {
                sections.append(
                    NCMediaSection(
                        yearMonth: yearMonth,
                        compactMetadatas: [metadata]
                    )
                )
            }
        }

        return sections
    }
}

public struct NCYearMonth: Hashable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init?(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)

        guard let year = components.year,
              let month = components.month else {
            return nil
        }

        self.init(year: year, month: month)
    }
}
