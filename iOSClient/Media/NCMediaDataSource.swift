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
    func loadDataSource() {
        let session = self.session
        DispatchQueue.global().async {
            if let metadatas = self.database.getResultsMetadatas(predicate: self.imageCache.getMediaPredicate(filterLivePhotoFile: true, session: session, showOnlyImages: self.showOnlyImages, showOnlyVideos: self.showOnlyVideos), sortedByKeyPath: "date") {
                self.dataSource = NCMediaDataSource(metadatas: metadatas)
            }
            self.collectionViewReloadData()
        }
    }

    func collectionViewReloadData() {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.refreshControl.endRefreshing()
            self.setTitleDate()
        }
    }

    // MARK: - Search media

    @objc func searchMediaUI(_ distant: Bool = false) {
        let session = self.session

        self.lockQueue.sync {
            guard self.isViewActived,
                  !self.hasRunSearchMedia,
                  !self.isPinchGestureActive,
                  !self.showOnlyImages,
                  !self.showOnlyVideos,
                  !isEditMode,
                  NCNetworking.shared.downloadThumbnailQueue.operationCount == 0,
                  let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account))
            else { return }
            self.hasRunSearchMedia = true

            let limit = max(collectionView.visibleCells.count * 3, 300)
            var lessDate = Date.distantFuture
            var greaterDate = Date.distantPast
            let countMetadatas = self.dataSource.metadatas.count
            let options = NKRequestOptions(timeout: 120, taskDescription: global.taskDescriptionRetrievesProperties, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
            var firstCellDate: Date?
            var lastCellDate: Date?

            if countMetadatas == 0 {
                self.collectionViewReloadData()
            }

            if let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) }), !distant {

                firstCellDate = (visibleCells.first as? NCMediaCell)?.date
                if firstCellDate == self.dataSource.metadatas.first?.date {
                    lessDate = Date.distantFuture
                } else {
                    if let date = firstCellDate {
                        lessDate = Calendar.current.date(byAdding: .second, value: 1, to: date)!
                    } else {
                        lessDate = Date.distantFuture
                    }
                }

                lastCellDate = (visibleCells.last as? NCMediaCell)?.date
                if lastCellDate == self.dataSource.metadatas.last?.date {
                    greaterDate = Date.distantPast
                } else {
                    if let date = lastCellDate {
                        greaterDate = Calendar.current.date(byAdding: .second, value: -1, to: date)!
                    } else {
                        greaterDate = Date.distantPast
                    }
                }
            }

            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Start searchMedia with lessDate \(lessDate), greaterDate \(greaterDate), limit \(limit)")

            activityIndicator.startAnimating()

            NextcloudKit.shared.searchMedia(path: tableAccount.mediaPath,
                                            lessDate: lessDate,
                                            greaterDate: greaterDate,
                                            elementDate: "d:getlastmodified/",
                                            limit: limit,
                                            showHiddenFiles: NCKeychain().showHiddenFiles,
                                            account: self.session.account,
                                            options: options) { account, files, _, error in

                if error == .success, let files, session.account == account, !self.showOnlyImages, !self.showOnlyVideos {
                    /// No files, remove all
                    if lessDate == Date.distantFuture, greaterDate == Date.distantPast, files.isEmpty {
                        self.dataSource.metadatas.removeAll()
                        self.collectionViewReloadData()
                    }

                    DispatchQueue.global().async {
                        self.database.convertFilesToMetadatas(files, useFirstAsMetadataFolder: false) { _, metadatas in
                            let metadatas = metadatas.filter { metadata in
                                if let tableMetadata = self.database.getMetadataFromOcId(metadata.ocId) {
                                    return tableMetadata.status == self.global.metadataStatusNormal
                                } else {
                                    return true
                                }
                            }
                            self.database.addMetadatas(metadatas)

                            if self.dataSource.addMetadatas(metadatas) {
                                self.collectionViewReloadData()
                            }

                            DispatchQueue.main.async {
                                if let firstCellDate, let lastCellDate, self.isViewActived {
                                    DispatchQueue.global().async {
                                        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [ NSPredicate(format: "date >= %@ AND date =< %@", lastCellDate as NSDate, firstCellDate as NSDate), self.imageCache.getMediaPredicate(filterLivePhotoFile: false, session: session, showOnlyImages: self.showOnlyImages, showOnlyVideos: self.showOnlyVideos)])

                                        if let resultsMetadatas = NCManageDatabase.shared.getResultsMetadatas(predicate: predicate) {
                                            for metadata in resultsMetadatas where !self.filesExists.contains(metadata.ocId) {
                                                if NCNetworking.shared.fileExistsQueue.operations.filter({ ($0 as? NCOperationFileExists)?.ocId == metadata.ocId }).isEmpty {
                                                    NCNetworking.shared.fileExistsQueue.addOperation(NCOperationFileExists(metadata: metadata))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                } else {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media error code \(error.errorCode) " + error.errorDescription)
                    self.collectionViewReloadData()
                }

                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                }

                self.hasRunSearchMedia = false
            }
        }
    }
}

// MARK: -

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
    var metadatas: [Metadata] = []

    override init() { super.init() }

    init(metadatas: Results<tableMetadata>) {
        super.init()

        self.metadatas.removeAll()
        metadatas.forEach { metadata in
            let metadata = getMetadataFromTableMetadata(metadata)
            self.metadatas.append(metadata)
        }
    }

    private func insertInMetadatas(metadata: Metadata) {
        for i in 0..<self.metadatas.count {
            if (metadata.date as Date) > self.metadatas[i].date {
                self.metadatas.insert(metadata, at: i)
                return
            }
        }

        self.metadatas.append(metadata)
    }

    private func getMetadataFromTableMetadata(_ metadata: tableMetadata) -> Metadata {
        return Metadata(date: metadata.date as Date,
                        etag: metadata.etag,
                        imageSize: CGSize(width: metadata.width, height: metadata.height),
                        isImage: metadata.classFile == NKCommon.TypeClassFile.image.rawValue,
                        isLivePhoto: !metadata.livePhotoFile.isEmpty,
                        isVideo: metadata.classFile == NKCommon.TypeClassFile.video.rawValue,
                        ocId: metadata.ocId)
    }

    // MARK: -

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
                self.metadatas = self.metadatas.sorted { $0.date > $1.date }
            }
            return true
        }

        return false
    }
}
