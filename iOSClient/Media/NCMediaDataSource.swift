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
    func getPredicate(showAll: Bool = false) -> NSPredicate {
        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId) + mediaPath

        if showAll {
            return NSPredicate(format: NCImageCache.shared.showAllPredicateMediaString, appDelegate.account, startServerUrl)
        } else if showOnlyImages {
            return NSPredicate(format: NCImageCache.shared.showOnlyPredicateMediaString, appDelegate.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else if showOnlyVideos {
            return NSPredicate(format: NCImageCache.shared.showOnlyPredicateMediaString, appDelegate.account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        } else {
           return NSPredicate(format: NCImageCache.shared.showBothPredicateMediaString, appDelegate.account, startServerUrl)
        }
    }

    @objc func reloadDataSource() {
        guard !appDelegate.account.isEmpty else { return }

        self.metadatas = NCImageCache.shared.getMediaMetadatas(account: self.appDelegate.account, predicate: self.getPredicate())
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.mediaCommandView?.setTitleDate()
        }
    }

    // MARK: - Search media

    @objc func searchMediaUI() {
        var lessDate: Date?
        var greaterDate: Date?
        let firstMetadataDate = metadatas?.first?.date as? Date
        let lastMetadataDate = metadatas?.last?.date as? Date
        let countMetadatas = self.metadatas?.count ?? 0

        guard loadingTask == nil, !isEditMode else {
            return
        }

        if let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) }) {
            // first date
            let firstCellDate = (visibleCells.first as? NCGridMediaCell)?.fileDate
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
            let lastCellDate = (visibleCells.last as? NCGridMediaCell)?.fileDate
            if lastCellDate == lastMetadataDate {
                greaterDate = Date.distantPast
            } else {
                if let date = lastCellDate {
                    greaterDate = Calendar.current.date(byAdding: .second, value: -1, to: date)!
                } else {
                    greaterDate = Date.distantPast
                }
            }

            if let lessDate, let greaterDate {
                mediaCommandView?.activityIndicator.startAnimating()
                loadingTask = Task.detached {
                    if countMetadatas == 0 {
                        await self.collectionView.reloadData()
                    }
                    let results = await self.searchMedia(account: self.appDelegate.account, lessDate: lessDate, greaterDate: greaterDate)
                    print("Media results changed items: \(results.isChanged)")
                    await self.mediaCommandView?.activityIndicator.stopAnimating()
                    Task { @MainActor in
                        self.loadingTask = nil
                    }
                    if results.error != .success {
                        NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media error code \(results.error.errorCode) " + results.error.errorDescription)
                    } else if results.error == .success, results.lessDate == Date.distantFuture, results.greaterDate == Date.distantPast, !results.isChanged, results.metadatasCount == 0 {
                        Task { @MainActor in
                            self.metadatas = nil
                        }
                    }
                    if results.isChanged {
                        await self.reloadDataSource()
                    } else {
                        if countMetadatas == 0 {
                            await self.collectionView.reloadData()
                        }
                    }
                }
            }
        }
    }

    func searchMedia(account: String, lessDate: Date, greaterDate: Date, limit: Int = 300, timeout: TimeInterval = 120) async -> (account: String, lessDate: Date?, greaterDate: Date?, metadatasCount: Int, isChanged: Bool, error: NKError) {

        guard let mediaPath = NCManageDatabase.shared.getActiveAccount()?.mediaPath else {
            return(account, lessDate, greaterDate, 0, false, NKError())
        }
        let options = NKRequestOptions(timeout: timeout, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        let results = await NextcloudKit.shared.searchMedia(path: mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: NCKeychain().showHiddenFiles, includeHiddenFiles: [], options: options)

        if results.account == account, results.error == .success {
            let metadatas = await NCManageDatabase.shared.convertFilesToMetadatas(results.files, useMetadataFolder: false).metadatas
            var predicate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self.getPredicate(showAll: true)])
            let resultsUpdate = NCManageDatabase.shared.updateMetadatas(metadatas, predicate: predicate)
            let isChaged: Bool = resultsUpdate.metadatasChanged || resultsUpdate.metadatasChangedCount != 0
            return(account, lessDate, greaterDate, metadatas.count, isChaged, results.error)
        } else {
            return(account, lessDate, greaterDate, 0, false, results.error)
        }
    }
}
