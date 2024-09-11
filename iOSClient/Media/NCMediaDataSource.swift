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

extension NCMedia {
    func reloadDataSource() {
        DispatchQueue.global().async {
            if let metadatas = self.database.getResultsMetadatas(predicate: self.getPredicate(filterLivePhotoFile: true), sortedByKeyPath: "date") {
                self.dataSource = NCMediaDataSource(metadatas: metadatas)
            }
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.refreshControl.endRefreshing()
                self.setTitleDate()
            }
        }
    }

    // MARK: - Search media

    @objc func searchMediaUI(_ distant: Bool = false) {
        self.lockQueue.sync {
            guard !self.hasRun,
                  !isEditMode,
                  NCNetworking.shared.downloadThumbnailQueue.operationCount == 0,
                  let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account))
            else { return }
            self.hasRun = true

            var limit = 300
            var lessDate = Date.distantFuture
            var greaterDate = Date.distantPast
            let countMetadatas = self.dataSource.getMetadatas().count
            let options = NKRequestOptions(timeout: 120, taskDescription: self.taskDescriptionRetrievesProperties, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
            var firstCellDate: Date?
            var lastCellDate: Date?

            if countMetadatas == 0 {
                collectionView.reloadData()
                setTitleDate()
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

            if collectionView.visibleCells.count + 100 > limit {
                limit = collectionView.visibleCells.count + 100
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
                if error == .success,
                   let files,
                   // let greaterDate = files.min(by: { $0.date < $1.date })?.date,
                   // let lessDate = files.max(by: { $0.date < $1.date })?.date,
                   self.session.account == account {

                    self.database.convertFilesToMetadatas(files, useFirstAsMetadataFolder: false) { _, metadatas in
                        self.database.addMetadatas(metadatas)

                        if let firstCellDate, let lastCellDate {
                            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [ NSPredicate(format: "date >= %@ AND date =< %@", lastCellDate as NSDate, firstCellDate as NSDate), self.getPredicate(filterLivePhotoFile: false)])

                            if let resultsMetadatas = NCManageDatabase.shared.getResultsMetadatas(predicate: predicate) {
                                print(resultsMetadatas.count)
                                for metadata in resultsMetadatas {
                                    if NCNetworking.shared.fileExistsQueue.operations.filter({ ($0 as? NCOperationFileExists)?.ocId == metadata.ocId }).isEmpty {
                                        NCNetworking.shared.fileExistsQueue.addOperation(NCOperationFileExists(metadata: metadata))
                                    }
                                }
                            }
                        }

                        if lessDate == Date.distantFuture, greaterDate == Date.distantPast, metadatas.count == 0 {
                            self.dataSource.removeAll()
                            DispatchQueue.main.async {
                                self.collectionView.reloadData()
                                self.setTitleDate()
                            }
                        } else {
                            self.reloadDataSource()
                        }
                    }
                } else if error == .success {
                    self.reloadDataSource()
                } else {
                    DispatchQueue.main.async {
                        NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media error code \(error.errorCode) " + error.errorDescription)
                        self.collectionView.reloadData()
                        self.setTitleDate()
                    }
                }
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                }
                self.hasRun = false
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
        let account: String
        let date: Date
        let etag: String
        let etagResource: String
        let fileId: String
        let imageSize: CGSize
        let isImage: Bool
        let isNotFlaggedAsLivePhotoByServer: Bool
        let isLivePhoto: Bool
        let isVideo: Bool
        let ocId: String
        let serverUrl: String
        let user: String

        init(account: String,
             date: Date,
             etag: String,
             fileId: String,
             etagResource: String,
             imageSize: CGSize,
             isImage: Bool,
             isNotFlaggedAsLivePhotoByServer: Bool,
             isLivePhoto: Bool,
             isVideo: Bool,
             ocId: String,
             serverUrl: String,
             user: String) {
            self.account = account
            self.date = date
            self.etag = etag
            self.fileId = fileId
            self.etagResource = etagResource
            self.imageSize = imageSize
            self.isImage = isImage
            self.isNotFlaggedAsLivePhotoByServer = isNotFlaggedAsLivePhotoByServer
            self.isLivePhoto = isLivePhoto
            self.isVideo = isVideo
            self.ocId = ocId
            self.serverUrl = serverUrl
            self.user = user
        }
    }

    private let utilityFileSystem = NCUtilityFileSystem()
    private let global = NCGlobal.shared
    private var metadatas: [Metadata] = []

    override init() { super.init() }

    init(metadatas: [tableMetadata]) {
        super.init()
        self.metadatas.removeAll()
        for metadata in metadatas {
            appendMetadata(metadata)
        }
    }

    internal func appendMetadata(_ metadata: tableMetadata) {
        self.metadatas.append(Metadata(account: metadata.account,
                                       date: metadata.date as Date,
                                       etag: metadata.etag,
                                       fileId: metadata.fileId,
                                       etagResource: metadata.etagResource,
                                       imageSize: CGSize(width: metadata.width, height: metadata.height),
                                       isImage: metadata.classFile == NKCommon.TypeClassFile.image.rawValue,
                                       isNotFlaggedAsLivePhotoByServer: !metadata.isFlaggedAsLivePhotoByServer,
                                       isLivePhoto: !metadata.livePhotoFile.isEmpty,
                                       isVideo: metadata.classFile == NKCommon.TypeClassFile.video.rawValue,
                                       ocId: metadata.ocId,
                                       serverUrl: metadata.serverUrl,
                                       user: metadata.urlBase))
    }

    // MARK: -

    func removeAll() {
        self.metadatas.removeAll()
    }

    func isEmpty() -> Bool {
        return self.metadatas.isEmpty
    }

    func getMetadatas() -> [Metadata] {
        return self.metadatas
    }

    func getMetadata(indexPath: IndexPath) -> Metadata? {
        if indexPath.row < self.metadatas.count {
            return self.metadatas[indexPath.row]
        }
        return nil
    }

    func removeMetadata(_ ocId: [String]) {
        self.metadatas.removeAll { item in
            ocId.contains(item.ocId)
        }
    }

    func addMetadata(_ metadata: tableMetadata) {
        removeMetadata([metadata.ocId])
        appendMetadata(metadata)
    }
}
