//
//  NCMediaDataSource.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/01/24.
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

import UIKit
import NextcloudKit
import RealmSwift

extension NCMedia {
    func loadDataSource() async {
        guard let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", session.account)) else {
            return
        }
        let predicate = self.imageCache.getMediaPredicateAsync(filterLivePhotoFile: true, session: session, mediaPath: tblAccount.mediaPath, showOnlyImages: self.showOnlyImages, showOnlyVideos: self.showOnlyVideos)
        if let metadatas = await self.database.getMetadatasAsync(predicate: predicate, sortedByKeyPath: "datePhotosOriginal", ascending: false) {
            let filteredMetadatas = metadatas.filter { !self.ocIdDeleted.contains($0.ocId) }
            await MainActor.run {
                self.dataSource = NCMediaDataSource(metadatas: filteredMetadatas)
            }
        }
        self.collectionViewReloadData()
    }

    @MainActor
    func collectionViewReloadData() {
        self.collectionView.reloadData()
        self.refreshControl.endRefreshing()
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
        var firstCellDate: Date?
        var lastCellDate: Date?

        await MainActor.run {
            if self.dataSource.metadatas.isEmpty {
                self.collectionViewReloadData()
            }

            if let visibleCells = self.collectionView?.indexPathsForVisibleItems
                .sorted(by: { $0.row < $1.row })
                .compactMap({ self.collectionView?.cellForItem(at: $0) }) as? [NCMediaCell], !distant {

                firstCellDate = visibleCells.first?.datePhotosOriginal
                lastCellDate = visibleCells.last?.datePhotosOriginal

                if firstCellDate == self.dataSource.metadatas.first?.datePhotosOriginal {
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

        nkLog(start: "Start searchMedia with lessDate \(lessDate), greaterDate \(greaterDate)")

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

        let limit = await MainActor.run { max(self.collectionView.visibleCells.count * 3, 300) }

        let options = NKRequestOptions(timeout: 180, taskDescription: self.global.taskDescriptionRetrievesProperties, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let result = await NextcloudKit.shared.searchMediaAsync(path: tblAccount.mediaPath,
                                                                lessDate: lessDateAny,
                                                                greaterDate: greaterDateAny,
                                                                elementDate: elementDate,
                                                                limit: limit,
                                                                account: self.session.account,
                                                                options: options)

        guard result.error == .success, let files = result.files, !self.showOnlyImages, !self.showOnlyVideos else {
            nkLog(error: "Media search failed: \(result.error.errorDescription)")
            await MainActor.run {
                self.collectionViewReloadData()
                self.activityIndicator.stopAnimating()
                self.searchMediaInProgress = false
            }
            return
        }

        if lessDate == .distantFuture, greaterDate == .distantPast, files.isEmpty {
            await MainActor.run {
                self.dataSource.clearMetadatas()
                self.collectionViewReloadData()
            }
        }

        let mediaPredicate = self.imageCache.getMediaPredicateAsync(
            filterLivePhotoFile: false,
            session: session,
            mediaPath: tblAccount.mediaPath,
            showOnlyImages: self.showOnlyImages,
            showOnlyVideos: self.showOnlyVideos
        )

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let (_, metadatas) = await self.database.convertFilesToMetadatasAsync(files)

            let filtered = await metadatas.asyncFilter { metadata in
                if let stored = await self.database.getMetadataFromOcIdAsync(metadata.ocId) {
                    return stored.status == self.global.metadataStatusNormal
                } else {
                    return true
                }
            }

            if let firstCellDate, let lastCellDate {
                let datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "datePhotosOriginal >= %@ AND datePhotosOriginal <= %@", lastCellDate as NSDate, firstCellDate as NSDate),
                    mediaPredicate
                ])
                if let metadatas = await self.database.getMetadatasAsync(predicate: datePredicate) {
                    for metadata in metadatas where await !self.ocIdVerified.contains(metadata.ocId) {
                        if self.networking.fileExistsQueue.operations.filter({ ($0 as? NCOperationFileExists)?.ocId == metadata.ocId }).isEmpty {
                            self.networking.fileExistsQueue.addOperation(NCOperationFileExists(metadata: metadata))
                        }
                    }
                }
            }

            await self.database.addMetadatasAsync(filtered)

            if await self.dataSource.addMetadatas(metadatas) {
                await self.collectionViewReloadData()
            }

            await MainActor.run {
                self.activityIndicator.stopAnimating()
                self.searchMediaInProgress = false
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

    func addMetadatas(_ metadatas: [tableMetadata]) -> Bool {
        var newMetadatas: [Metadata] = []

        for tableMetadata in metadatas {
            let metadata = getMetadataFromTableMetadata(tableMetadata)

            // Skip invalid Live Photo case
            if metadata.isLivePhoto, metadata.isVideo {
                continue
            }

            if let index = self.metadatas.firstIndex(where: { $0.ocId == tableMetadata.ocId }) {
                self.metadatas[index] = metadata
            } else {
                newMetadatas.append(metadata)
            }
        }

        /*
         • For many new elements (e.g., hundreds or thousands): It might be more efficient to add all the elements and then sort, especially if the sorting cost  O(n \log n)  is manageable and the final sort is preferable to handling many individual insertions.
         • For a few new elements (fewer than 100): Inserting each element into the correct position might be simpler and less costly, particularly if the array isn’t too large.
         */

        guard !newMetadatas.isEmpty else {
            return false
        }

        if newMetadatas.count < 100 {
            for metadata in newMetadatas {
                self.insertInMetadatas(metadata: metadata)
            }
        } else {
            self.metadatas.append(contentsOf: newMetadatas)
            self.metadatas.sort { $0.datePhotosOriginal > $1.datePhotosOriginal }
        }

        return true
    }
}
