//
//  NCDataSource.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/09/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

class NCDataSource: NSObject {

    public var metadatas: [tableMetadata] = []
    public var metadataShare: [String: tableShare] = [:]
    public var metadataOffLine: [String] = []

    private var ascending: Bool = true
    private var sort: String = ""
    private var directoryOnTop: Bool = true
    private var favoriteOnTop: Bool = true
    private var filterLivePhoto: Bool = true

    override init() {
        super.init()
    }

    init(metadatasSource: [tableMetadata], sort: String? = "none", ascending: Bool? = false, directoryOnTop: Bool? = true, favoriteOnTop: Bool? = true, filterLivePhoto: Bool? = true) {
        super.init()

        self.sort = sort ?? "none"
        self.ascending = ascending ?? false
        self.directoryOnTop = directoryOnTop ?? true
        self.favoriteOnTop = favoriteOnTop ?? true
        self.filterLivePhoto = filterLivePhoto ?? true

        createMetadatas(metadatasSource: metadatasSource)
    }

    // MARK: -

    private func createMetadatas(metadatasSource: [tableMetadata]) {

        var metadatasSourceSorted: [tableMetadata] = []
        var metadataFavoriteDirectory: [tableMetadata] = []
        var metadataFavoriteFile: [tableMetadata] = []
        var metadataDirectory: [tableMetadata] = []
        var metadataFile: [tableMetadata] = []

        /*
        Metadata order
        */

        if sort != "none" && sort != "" {
            metadatasSourceSorted = metadatasSource.sorted { (obj1: tableMetadata, obj2: tableMetadata) -> Bool in
                if sort == "date" {
                    if ascending {
                        return obj1.date.compare(obj2.date as Date) == ComparisonResult.orderedAscending
                    } else {
                        return obj1.date.compare(obj2.date as Date) == ComparisonResult.orderedDescending
                    }
                } else if sort == "size" {
                    if ascending {
                        return obj1.size < obj2.size
                    } else {
                        return obj1.size > obj2.size
                    }
                } else {
                    if ascending {
                        return obj1.fileNameView.localizedStandardCompare(obj2.fileNameView) == ComparisonResult.orderedAscending
                    } else {
                        return obj1.fileNameView.localizedStandardCompare(obj2.fileNameView) == ComparisonResult.orderedDescending
                    }
                }
            }
        } else {
            metadatasSourceSorted = metadatasSource
        }

        /*
        Initialize datasource
        */

        for metadata in metadatasSourceSorted {

            // skipped the root file
            if metadata.fileName == "." || metadata.serverUrl == ".." {
                continue
            }

            // skipped livePhoto
            if metadata.ext == "mov" && metadata.livePhoto && filterLivePhoto {
                continue
            }

            // share
            let shares = NCManageDatabase.shared.getTableShares(account: metadata.account, serverUrl: metadata.serverUrl, fileName: metadata.fileName)
            if shares.count > 0 {
                metadataShare[metadata.ocId] = shares.first
            }

            // is Local / offline
            if !metadata.directory {
                let size = CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView)
                if size > 0 {
                    let tableLocalFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    if tableLocalFile == nil && size == metadata.size {
                        NCManageDatabase.shared.addLocalFile(metadata: metadata)
                    }
                    if tableLocalFile?.offline ?? false {
                        metadataOffLine.append(metadata.ocId)
                    }
                }
            }

            // Organized the metadata
            if metadata.favorite && favoriteOnTop {
                if metadata.directory {
                    metadataFavoriteDirectory.append(metadata)
                } else {
                    metadataFavoriteFile.append(metadata)
                }
            } else if  metadata.directory && directoryOnTop {
                metadataDirectory.append(metadata)
            } else {
                metadataFile.append(metadata)
            }
        }

        metadatas.removeAll()
        metadatas += metadataFavoriteDirectory
        metadatas += metadataFavoriteFile
        metadatas += metadataDirectory
        metadatas += metadataFile
    }

    // MARK: -

    func getFilesInformation() -> (directories: Int, files: Int, size: Int64) {

        var directories: Int = 0
        var files: Int = 0
        var size: Int64 = 0

        for metadata in metadatas {
            if metadata.directory {
                directories += 1
            } else {
                files += 1
            }
            size += metadata.size
        }

        return (directories, files, size)
    }

    func deleteMetadata(ocId: String) -> Int? {

        if let index = self.getIndexMetadata(ocId: ocId) {
            metadatas.remove(at: index)
            return index
        }

        return nil
    }

    @discardableResult
    func reloadMetadata(ocId: String, ocIdTemp: String? = nil) -> Int? {

        var index: Int?

        if ocIdTemp != nil {
            index = self.getIndexMetadata(ocId: ocIdTemp!)
        } else {
            index = self.getIndexMetadata(ocId: ocId)
        }

        if index != nil {
            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                metadatas[index!] = metadata
            }
        }

        return index
    }

    @discardableResult
    func addMetadata(_ metadata: tableMetadata) -> Int? {

        var index: Int = 0

        // Already exists
        for metadataCount in metadatas {
            if metadataCount.fileNameView == metadata.fileNameView || metadataCount.ocId == metadata.ocId {
                metadatas[index] = metadata
                return index
            }
            index += 1
        }

        // Append & rebuild
        metadatas.append(metadata)
        createMetadatas(metadatasSource: metadatas)

        return getIndexMetadata(ocId: metadata.ocId)
    }

    func getIndexMetadata(ocId: String) -> Int? {

        var index: Int = 0

        for metadataCount in metadatas {
            if metadataCount.ocId == ocId {
                return index
            }
            index += 1
        }

        return nil
    }

    func numberOfItems() -> Int {

        return metadatas.count
    }

    func cellForItemAt(indexPath: IndexPath) -> tableMetadata? {

        let row = indexPath.row

        if row > metadatas.count - 1 {
            return nil
        } else {
            return metadatas[row]
        }
    }
}
