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
        DispatchQueue.global(qos: .userInteractive).async {
            let metadatas = self.database.getResultsMediaMetadatas(predicate: self.getPredicate())
            self.dataSource = NCMediaDataSource(metadatas: metadatas)
            self.collectionViewReloadData()
        }
    }

    func collectionViewReloadData() {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.setTitleDate()
        }
    }

    // MARK: - Search media

    @objc func searchMediaUI() {
        guard loadingTask == nil,
              !isEditMode,
              self.viewIfLoaded?.window != nil,
              let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) }),
              let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account))
        else {
            return
        }

        var lessDate: Date?
        var greaterDate: Date?
        let firstMetadataDate = dataSource.getMetadatas().first?.date
        let lastMetadataDate = dataSource.getMetadatas().last?.date
        let countMetadatas = dataSource.getMetadatas().count

        // first date
        let firstCellDate = (visibleCells.first as? NCGridMediaCell)?.date
        if firstCellDate == firstMetadataDate {
            lessDate = Date.distantFuture
        } else {
            if let date = firstCellDate {
                lessDate = Calendar.current.date(byAdding: .second, value: 1, to: date)!
            } else {
                lessDate = Date.distantFuture
            }
        }
        // last date
        let lastCellDate = (visibleCells.last as? NCGridMediaCell)?.date
        if lastCellDate == lastMetadataDate {
            greaterDate = Date.distantPast
        } else {
            if let date = lastCellDate {
                greaterDate = Calendar.current.date(byAdding: .second, value: -1, to: date)!
            } else {
                greaterDate = Date.distantPast
            }
        }

        if lessDate == Date.distantFuture,
           greaterDate == Date.distantPast,
           countMetadatas > visibleCells.count {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media oops. something is bad (distantFuture, distantPast): \(countMetadatas)")
            return
        }

        if let lessDate, let greaterDate {
            activityIndicator.startAnimating()
            loadingTask = Task.detached {
                if countMetadatas == 0 {
                    await self.collectionViewReloadData()
                }

                var limit = 300
                if await self.collectionView.visibleCells.count * 2 > limit {
                    limit = await self.collectionView.visibleCells.count * 2
                }

                NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Start searchMedia with lessDate \(lessDate), greaterDate \(greaterDate) with limit \(limit)")

                let options = NKRequestOptions(timeout: 120, taskDescription: self.taskDescriptionRetrievesProperties, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
                let results = await NCNetworking.shared.searchMedia(path: tableAccount.mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: NCKeychain().showHiddenFiles, account: self.session.account, options: options)

                if results.error == .success, let files = results.files {
                    var predicate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                    predicate = await NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self.getPredicate(showAll: true)])

                    let metadatas = await self.database.convertFilesToMetadatas(files, useFirstAsMetadataFolder: false).metadatas
                    let resultsUpdate = self.database.updateMetadatas(metadatas, predicate: predicate)
                    let isChanged: Bool = (resultsUpdate.metadatasDifferentCount != 0 || resultsUpdate.metadatasModified != 0)
                    NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] End searchMedia UpdateMetadatas with differentCount \(resultsUpdate.metadatasDifferentCount), modified \(resultsUpdate.metadatasModified)")

                    Task { @MainActor in
                        if lessDate == Date.distantFuture, greaterDate == Date.distantPast, !isChanged, metadatas.count == 0 {
                            self.dataSource.removeAll()
                            self.collectionViewReloadData()
                            print("searchMediaUI: metadatacount 0")
                        } else if isChanged {
                            self.reloadDataSource()
                            print("searchMediaUI: changed")
                        } else {
                            print("searchMediaUI: nothing")
                        }
                    }

                } else {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media error code \(results.error.errorCode) " + results.error.errorDescription)
                }

                Task { @MainActor in
                    self.loadingTask = nil
                    self.activityIndicator.stopAnimating()
                }
            }
        }
    }

    func getPredicate(showAll: Bool = false) -> NSPredicate {
        guard let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) else { return NSPredicate() }
        let startServerUrl = NCUtilityFileSystem().getHomeServer(session: session) + tableAccount.mediaPath

        if showAll {
            return NSPredicate(format: showAllPredicateMediaString, session.account, startServerUrl)
        } else if showOnlyImages {
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
