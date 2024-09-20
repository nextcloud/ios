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
        DispatchQueue.global().async {
            if let metadatas = self.database.getResultsMetadatas(predicate: self.getPredicate(filterLivePhotoFile: true), sortedByKeyPath: "date") {
                self.dataSource = NCMediaDataSource(metadatas: metadatas)
            }
            self.collectionViewReloadData()
        }
    }

    func collectionViewReloadData() {
        DispatchQueue.main.async {
            self.refreshControl.endRefreshing()
            self.collectionView.reloadData()
            self.setTitleDate()
        }
    }

    // MARK: - Search media

    @objc func searchMediaUI(_ distant: Bool = false) {
        self.lockQueue.sync {
            guard self.isViewActived,
                  !self.hasRunSearchMedia,
                  !self.transitionColumns,
                  !isEditMode,
                  NCNetworking.shared.downloadThumbnailQueue.operationCount == 0,
                  let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account))
            else { return }
            self.hasRunSearchMedia = true

            let limit = max(collectionView.visibleCells.count * 2, 300)
            var lessDate = Date.distantFuture
            var greaterDate = Date.distantPast
            let countMetadatas = self.dataSource.getMetadatas().count
            let options = NKRequestOptions(timeout: 120, taskDescription: self.taskDescriptionRetrievesProperties, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
            var firstCellDate: Date?
            var lastCellDate: Date?

            if countMetadatas == 0 {
                self.collectionViewReloadData()
            }

            if let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) }), !distant {

                firstCellDate = (visibleCells.first as? NCGridMediaCell)?.date
                if firstCellDate == self.dataSource.getMetadatas().first?.date {
                    lessDate = Date.distantFuture
                } else {
                    if let date = firstCellDate {
                        lessDate = Calendar.current.date(byAdding: .second, value: 1, to: date)!
                    } else {
                        lessDate = Date.distantFuture
                    }
                }

                lastCellDate = (visibleCells.last as? NCGridMediaCell)?.date
                if lastCellDate == self.dataSource.getMetadatas().last?.date {
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

                if error == .success, let files, self.session.account == account {

                    /// Removes all files in `files` that have an `ocId` present in `fileDeleted`
                    var files = files
                    files.removeAll { file in
                        self.fileDeleted.contains(file.ocId)
                    }
                    self.fileDeleted.removeAll()

                    /// No files, remove all
                    if lessDate == Date.distantFuture, greaterDate == Date.distantPast, files.isEmpty {
                        self.dataSource.removeAll()
                        self.collectionViewReloadData()
                    }

                    DispatchQueue.global(qos: .background).async {
                        self.database.convertFilesToMetadatas(files, useFirstAsMetadataFolder: false) { _, metadatas in
                            self.database.addMetadatas(metadatas)

                            if let firstCellDate, let lastCellDate, self.isViewActived {
                                let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [ NSPredicate(format: "date >= %@ AND date =< %@", lastCellDate as NSDate, firstCellDate as NSDate), self.getPredicate(filterLivePhotoFile: false)])

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

                    if self.dataSource.addFiles(files) {
                        self.collectionViewReloadData()
                    }

                } else {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media error code \(error.errorCode) " + error.errorDescription)
                }

                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                }

                self.hasRunSearchMedia = false
            }
        }
    }

    func getPredicate(filterLivePhotoFile: Bool) -> NSPredicate {
        guard let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) else { return NSPredicate() }
        let startServerUrl = NCUtilityFileSystem().getHomeServer(session: session) + tableAccount.mediaPath

        var showBothPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND hasPreview == true AND (classFile == '\(NKCommon.TypeClassFile.image.rawValue)' OR classFile == '\(NKCommon.TypeClassFile.video.rawValue)') AND NOT (session CONTAINS[c] 'upload')"
        var showOnlyPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND hasPreview == true AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')"

        if filterLivePhotoFile {
            showBothPredicateMediaString = showBothPredicateMediaString + " AND NOT (livePhotoFile != '' AND classFile == '\(NKCommon.TypeClassFile.video.rawValue)')"
            showOnlyPredicateMediaString = showOnlyPredicateMediaString + " AND NOT (livePhotoFile != '' AND classFile == '\(NKCommon.TypeClassFile.video.rawValue)')"
        }

        if showOnlyImages {
            return NSPredicate(format: showOnlyPredicateMediaString, session.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else if showOnlyVideos {
            return NSPredicate(format: showOnlyPredicateMediaString, session.account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        } else {
            return NSPredicate(format: showBothPredicateMediaString, session.account, startServerUrl)
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
    private var metadatas: [Metadata] = []
    private var tableMetadatas: Results<tableMetadata>?

    override init() { super.init() }

    init(metadatas: Results<tableMetadata>) {
        super.init()

        self.metadatas.removeAll()
        for metadata in metadatas {
            let metadata = getMetadataFromTableMetadata(metadata)
            self.metadatas.append(metadata)
        }

        let reference = ThreadSafeReference(to: metadatas)
        DispatchQueue.main.async {
            do {
                let realm = try Realm()
                self.tableMetadatas = realm.resolve(reference)
            } catch let error as NSError {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
            }
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

    private func getMetadataFromFile(_ file: NKFile) -> Metadata {
        return Metadata(date: file.date as Date,
                        etag: file.etag,
                        imageSize: CGSize(width: file.width, height: file.height),
                        isImage: file.classFile == NKCommon.TypeClassFile.image.rawValue,
                        isLivePhoto: !file.livePhotoFile.isEmpty,
                        isVideo: file.classFile == NKCommon.TypeClassFile.video.rawValue,
                        ocId: file.ocId)
    }

    // MARK: -

    func removeAll() {
        self.metadatas.removeAll()
    }

    func isEmpty() -> Bool {
        return self.metadatas.isEmpty
    }

    func count() -> Int {
        return self.metadatas.count
    }

    func getMetadatas() -> [Metadata] {
        return self.metadatas
    }

    func getTableMetadatas() -> Results<tableMetadata>? {
        return self.tableMetadatas
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

    func addFiles(_ files: [NKFile]) -> Bool {
        var metadatasToInsert: [Metadata] = []

        for file in files {
            let metadata = getMetadataFromFile(file)

            if metadata.isLivePhoto, metadata.isVideo { continue }

            if let index = self.metadatas.firstIndex(where: { $0.ocId == file.ocId }) {
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
