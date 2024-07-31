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
        self.metadatas = imageCache.getMediaMetadatas(account: activeAccount.account, predicate: self.getPredicate())
        self.collectionViewReloadData()
    }

    func collectionViewReloadData() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.collectionView.reloadData()
            self.setTitleDate()
        }
    }

    // MARK: - Search media

    @objc func searchMediaUI() {
        var lessDate: Date?
        var greaterDate: Date?
        let firstMetadataDate = metadatas?.first?.date as? Date
        let lastMetadataDate = metadatas?.last?.date as? Date
        let countMetadatas = self.metadatas?.count ?? 0

        guard loadingTask == nil,
              !isEditMode,
              self.viewIfLoaded?.window != nil,
              let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) })
        else {
            return
        }

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
           (self.metadatas?.count ?? 0) > visibleCells.count {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media oops. something is bad (distantFuture, distantPast): \(self.activeAccount.account), \(self.appDelegate.account), \(self.metadatas?.count ?? 0)")
            return
        }

        if let lessDate, let greaterDate {
            activityIndicator.startAnimating()
            loadingTask = Task.detached {
                if countMetadatas == 0 {
                    await self.collectionViewReloadData()
                }
                let results = await self.searchMedia(lessDate: lessDate, greaterDate: greaterDate)
                if results.error == .success {
                    Task { @MainActor in
                        if results.lessDate == Date.distantFuture, results.greaterDate == Date.distantPast, !results.isChanged, results.metadatasCount == 0 {
                            self.metadatas = nil
                            self.collectionViewReloadData()
                            print("searchMediaUI: metadatacount 0")
                        } else if results.isChanged {
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

    private func searchMedia(lessDate: Date, greaterDate: Date, limit: Int = 300, timeout: TimeInterval = 120) async -> (lessDate: Date?, greaterDate: Date?, metadatasCount: Int, isChanged: Bool, error: NKError) {
        if UIApplication.shared.applicationState == .background {
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Media not reload datasource network with the application in background")
            return(lessDate, greaterDate, 0, false, NKError())
        }

        guard let mediaPath = NCManageDatabase.shared.getActiveAccount()?.mediaPath else {
            return(lessDate, greaterDate, 0, false, NKError())
        }
        NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Start searchMedia with lessDate \(lessDate), greaterDate \(greaterDate)")
        let options = NKRequestOptions(timeout: timeout, taskDescription: self.taskDescriptionRetrievesProperties, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        let results = await NCNetworking.shared.searchMedia(path: mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: NCKeychain().showHiddenFiles, includeHiddenFiles: [], account: activeAccount.account, options: options)
        if results.account != self.activeAccount.account {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "User changed")
            return(lessDate, greaterDate, 0, false, error)
        } else if results.error == .success {
            let metadatas = await NCManageDatabase.shared.convertFilesToMetadatas(results.files, useFirstAsMetadataFolder: false).metadatas
            var predicate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, getPredicate(showAll: true)])
            let resultsUpdate = NCManageDatabase.shared.updateMetadatas(metadatas, predicate: predicate)
            let isChaged: Bool = (resultsUpdate.metadatasDifferentCount != 0 || resultsUpdate.metadatasModified != 0)
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] End searchMedia UpdateMetadatas with differentCount \(resultsUpdate.metadatasDifferentCount), modified \(resultsUpdate.metadatasModified)")
            return(lessDate, greaterDate, metadatas.count, isChaged, results.error)
        } else {
            return(lessDate, greaterDate, 0, false, results.error)
        }
    }

    private func getPredicate(showAll: Bool = false) -> NSPredicate {
        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: activeAccount.urlBase, userId: activeAccount.userId) + activeAccount.mediaPath

        if showAll {
            return NSPredicate(format: imageCache.showAllPredicateMediaString, activeAccount.account, startServerUrl)
        } else if showOnlyImages {
            return NSPredicate(format: imageCache.showOnlyPredicateMediaString, activeAccount.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else if showOnlyVideos {
            return NSPredicate(format: imageCache.showOnlyPredicateMediaString, activeAccount.account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        } else {
            return NSPredicate(format: imageCache.showBothPredicateMediaString, activeAccount.account, startServerUrl)
        }
    }
}
