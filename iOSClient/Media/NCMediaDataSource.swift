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
        Task {
            guard let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", session.account)) else {
                return
            }
            let predicate = self.imageCache.getMediaPredicateAsync(filterLivePhotoFile: true, session: session, mediaPath: tblAccount.mediaPath, showOnlyImages: self.showOnlyImages, showOnlyVideos: self.showOnlyVideos)
            if let metadatas = await self.database.getMetadatasAsync(predicate: predicate, sortedByKeyPath: "datePhotosOriginal", ascending: false) {
                let filteredMetadatas = metadatas.filter { !self.ocIdDeleted.contains($0.ocId) }
                self.dataSource = NCMediaDataSource(metadatas: filteredMetadatas)
            }
            self.collectionViewReloadData()
        }
    }

    @MainActor
    func collectionViewReloadData() {
        self.collectionView.reloadData()
        self.refreshControl.endRefreshing()
        self.setTitleDate()
    }

    // MARK: - Search media

    func searchMediaUI(_ distant: Bool = false) async {
        guard self.isViewActived,
              !self.searchMediaInProgress,
              !self.isPinchGestureActive,
              !self.showOnlyImages,
              !self.showOnlyVideos,
              !isEditMode,
              networking.downloadThumbnailQueue.operationCount == 0,
              let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", session.account))
        else {
            return
        }
        self.searchMediaInProgress = true

        let limit = max(self.collectionView.visibleCells.count * 3, 300)
        let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) })
        let capabilities = await NKCapabilities.shared.getCapabilitiesAsync(for: session.account)

        var elementDate = "d:getlastmodified"
        var lessDate = Date.distantFuture
        var greaterDate = Date.distantPast
        var lessDateAny: Any = Date.distantFuture
        var greaterDateAny: Any = Date.distantPast
        let countMetadatas = self.dataSource.metadatas.count
        let options = NKRequestOptions(timeout: 120, taskDescription: self.global.taskDescriptionRetrievesProperties, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        var firstCellDate: Date?
        var lastCellDate: Date?

        if countMetadatas == 0 {
                self.collectionViewReloadData()
        }

        if let visibleCells, !distant {
            firstCellDate = (visibleCells.first as? NCMediaCell)?.datePhotosOriginal
            if firstCellDate == self.dataSource.metadatas.first?.datePhotosOriginal {
                lessDate = Date.distantFuture
            } else {
                if let date = firstCellDate {
                    lessDate = Calendar.current.date(byAdding: .second, value: 1, to: date)!
                } else {
                    lessDate = Date.distantFuture
                }
            }

            lastCellDate = (visibleCells.last as? NCMediaCell)?.datePhotosOriginal
            if lastCellDate == self.dataSource.metadatas.last?.datePhotosOriginal {
                greaterDate = Date.distantPast
            } else {
                if let date = lastCellDate {
                    greaterDate = Calendar.current.date(byAdding: .second, value: -1, to: date)!
                } else {
                    greaterDate = Date.distantPast
                }
            }
        }

        nkLog(start: "Start searchMedia with lessDate \(lessDate), greaterDate \(greaterDate), limit \(limit)")

        if capabilities.serverVersionMajor >= self.global.nextcloudVersion31 {
            elementDate = "nc:metadata-photos-original_date_time"
            lessDateAny = Int((lessDate as AnyObject).timeIntervalSince1970)
            greaterDateAny = Int((greaterDate as AnyObject).timeIntervalSince1970)
        } else {
            lessDateAny = lessDate
            greaterDateAny = greaterDate
        }

        self.activityIndicator.startAnimating()

        let resultsSearchMedia = await NextcloudKit.shared.searchMediaAsync(path: tblAccount.mediaPath,
                                                                            lessDate: lessDateAny,
                                                                            greaterDate: greaterDateAny,
                                                                            elementDate: elementDate,
                                                                            limit: limit,
                                                                            account: self.session.account,
                                                                            options: options) { _ in
        }

        if resultsSearchMedia.error == .success, let files = resultsSearchMedia.files, !self.showOnlyImages, !self.showOnlyVideos {
            // No files, remove all
            if lessDate == Date.distantFuture, greaterDate == Date.distantPast, files.isEmpty {
                self.dataSource.metadatas.removeAll()
                self.collectionViewReloadData()
            }

            let isViewActived = self.isViewActived
            let mediaPredicate = self.imageCache.getMediaPredicateAsync(filterLivePhotoFile: false, session: session, mediaPath: tblAccount.mediaPath, showOnlyImages: self.showOnlyImages, showOnlyVideos: self.showOnlyVideos)

            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let (_, metadatas) = await self.database.convertFilesToMetadatasAsync(files, useFirstAsMetadataFolder: false)

                let metadatasFiltered = await metadatas.asyncFilter { metadata in
                    if let tableMetadata = await self.database.getMetadataFromOcIdAsync(metadata.ocId) {
                        return tableMetadata.status == self.global.metadataStatusNormal
                    } else {
                        return true
                    }
                }

                if let firstCellDate, let lastCellDate, isViewActived {

                    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [ NSPredicate(format: "datePhotosOriginal >= %@ AND datePhotosOriginal =< %@", lastCellDate as NSDate, firstCellDate as NSDate), mediaPredicate])

                    if let metadatas = await self.database.getMetadatasAsync(predicate: predicate) {
                        for metadata in metadatas where await !ocIdVerified.contains(metadata.ocId) {
                            if networking.fileExistsQueue.operations.filter({ ($0 as? NCOperationFileExists)?.ocId == metadata.ocId }).isEmpty {
                                networking.fileExistsQueue.addOperation(NCOperationFileExists(metadata: metadata))
                            }
                        }
                    }
                }

                await self.database.addMetadatasAsync(metadatasFiltered)
                if await self.dataSource.addMetadatas(metadatas) {
                    await self.collectionViewReloadData()
                }

                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.searchMediaInProgress = false
                }
            }
        } else {
            nkLog(error: "Media search new media error code \(resultsSearchMedia.error.errorCode) " + resultsSearchMedia.error.errorDescription)

            self.collectionViewReloadData()
            self.activityIndicator.stopAnimating()
            self.searchMediaInProgress = false
        }
    }
}

// MARK: -

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
    var metadatas: [Metadata] = []

    override init() { super.init() }

    init(metadatas: [tableMetadata]) {
        super.init()

        self.metadatas.removeAll()
        metadatas.forEach { metadata in
            let metadata = getMetadataFromTableMetadata(metadata)
            self.metadatas.append(metadata)
        }
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
        var metadatasToInsert: [Metadata] = []

        for tableMetadata in metadatas {
            let metadata = getMetadataFromTableMetadata(tableMetadata)

            if metadata.isLivePhoto, metadata.isVideo { continue }

            if let index = self.metadatas.firstIndex(where: { $0.ocId == tableMetadata.ocId }) {
                self.metadatas[index] = metadata
            } else {
                metadatasToInsert.append(metadata)
            }
        }

        // • For many new elements (e.g., hundreds or thousands): It might be more efficient to add all the elements and then sort, especially if the sorting cost  O(n \log n)  is manageable and the final sort is preferable to handling many individual insertions.
        // • For a few new elements (fewer than 100): Inserting each element into the correct position might be simpler and less costly, particularly if the array isn’t too large.

        if !metadatasToInsert.isEmpty {
            if metadatasToInsert.count < 100 {
                for metadata in metadatasToInsert {
                    self.insertInMetadatas(metadata: metadata)
                }
            } else {
                for metadata in metadatasToInsert {
                    self.metadatas.append(metadata)
                }
                self.metadatas = self.metadatas.sorted { $0.datePhotosOriginal > $1.datePhotosOriginal }
            }
            return true
        }

        return false
    }
}
