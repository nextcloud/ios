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
    public var sections: [String] = []

    private var ascending: Bool = true
    private var sort: String = ""
    private var directoryOnTop: Bool = true
    private var favoriteOnTop: Bool = true
    private var filterLivePhoto: Bool = true
    private var groupByField: String = ""

    override init() {
        super.init()
    }

    init(metadatasSource: [tableMetadata], sort: String? = "none", ascending: Bool? = false, directoryOnTop: Bool? = true, favoriteOnTop: Bool? = true, filterLivePhoto: Bool? = true, groupByField: String = "name") {
        super.init()

        self.sort = sort ?? "none"
        self.ascending = ascending ?? false
        self.directoryOnTop = directoryOnTop ?? true
        self.favoriteOnTop = favoriteOnTop ?? true
        self.filterLivePhoto = filterLivePhoto ?? true
        self.groupByField = groupByField

        createMetadatas(metadatasSource: metadatasSource)
    }

    // MARK: -

    private func createMetadatas(metadatasSource: [tableMetadata]) {

        var metadatasSourceSorted: [tableMetadata] = []
        var metadataFavoriteDirectory: [tableMetadata] = []
        var metadataFavoriteFile: [tableMetadata] = []
        var metadataDirectory: [tableMetadata] = []
        var metadataFile: [tableMetadata] = []
        var sections: [String] = []

        /*
        Metadata order
        */

        if sort != "none" && sort != "" {
            metadatasSourceSorted = metadatasSource.sorted {

                switch sort {
                case "date":
                    if ascending {
                        return (getSectionField(metadata:$0), ($0.date as Date)) < (getSectionField(metadata:$1), ($1.date as Date))
                    } else {
                        return (getSectionField(metadata:$0), ($0.date as Date)) > (getSectionField(metadata:$1), ($1.date as Date))
                    }
                case "size":
                    if ascending {
                        return (getSectionField(metadata:$0), $0.size) < (getSectionField(metadata:$1), $1.size)
                    } else {
                        return (getSectionField(metadata:$0), $0.size) > (getSectionField(metadata:$1), $1.size)
                    }
                default:
                    if ascending {
                        return (getSectionField(metadata:$0), $0.fileNameView.lowercased()) < (getSectionField(metadata:$1), $1.fileNameView.lowercased())
                    } else {
                        return (getSectionField(metadata:$0), $0.fileNameView.lowercased()) > (getSectionField(metadata:$1), $1.fileNameView.lowercased())
                    }
                }
            }
        } else {
            metadatasSourceSorted = metadatasSource.sorted {
                (getSectionField(metadata:$0)) < (getSectionField(metadata:$1))
            }
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
            if !metadata.directory, CCUtility.fileProviderStorageExists(metadata) {
                let tableLocalFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                if tableLocalFile == nil {
                    NCManageDatabase.shared.addLocalFile(metadata: metadata)
                }
                if tableLocalFile?.offline ?? false {
                    metadataOffLine.append(metadata.ocId)
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

            // sections
            sections.append(getSectionField(metadata:metadata))
        }

        metadatas.removeAll()
        metadatas += metadataFavoriteDirectory
        metadatas += metadataFavoriteFile
        metadatas += metadataDirectory
        metadatas += metadataFile
        self.sections = Array(Set(sections))
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

    func deleteMetadata(ocId: String) -> IndexPath? {

        if let indexPath = self.getIndexPathMetadata(ocId: ocId) {
            metadatas.remove(at: indexPath.row)
            return indexPath
        }

        return nil
    }

    @discardableResult
    func reloadMetadata(ocId: String, ocIdTemp: String? = nil) -> IndexPath? {

        var indexPath: IndexPath?

        if let ocIdTemp = ocIdTemp {
            indexPath = self.getIndexPathMetadata(ocId: ocIdTemp)
        } else {
            indexPath = self.getIndexPathMetadata(ocId: ocId)
        }

        guard let indexPath = indexPath, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return nil }
        metadatas[indexPath.row] = metadata

        if CCUtility.fileProviderStorageExists(metadata) {
            let tableLocalFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            if tableLocalFile?.offline ?? false {
                metadataOffLine.append(metadata.ocId)
            }
        }

        return indexPath
    }

    @discardableResult
    func addMetadata(_ metadata: tableMetadata) -> IndexPath? {

        var row: Int = 0

        // Already exists
        for metadataCount in self.metadatas {
            if metadataCount.fileNameView == metadata.fileNameView || metadataCount.ocId == metadata.ocId {
                metadatas[row] = metadata
                let section = getSection(metadata: metadata)
                return IndexPath(row: row, section: section)
            }
            row += 1
        }

        // Append & rebuild
        metadatas.append(metadata)
        createMetadatas(metadatasSource: metadatas)

        return getIndexPathMetadata(ocId: metadata.ocId)
    }

    func getIndexPathMetadata(ocId: String) -> IndexPath? {

        var row: Int = 0

        for metadata in self.metadatas {
            if metadata.ocId == ocId {
                let section = getSection(metadata: metadata)
                return IndexPath(row: row, section: section)
            }
            row += 1
        }

        return nil
    }

    func numberOfSections() -> Int {

        if sections.count == 0 {
            return 1
        } else {
            return sections.count
        }
    }
    
    func numberOfItemsInSection(_ section: Int) -> Int {

        if self.sections.count == 0 || metadatas.count == 0 { return 0 }
        let sectionName = self.sections[section]
        let metadatas = self.metadatas.filter({ getSectionField(metadata: $0) == sectionName})

        return metadatas.count
    }

    func cellForItemAt(indexPath: IndexPath) -> tableMetadata? {

        let row = indexPath.row
        let sectionName = self.sections[indexPath.section]
        let metadatas = self.metadatas.filter({ getSectionField(metadata: $0) == sectionName})

        if row > metadatas.count - 1 {
            return nil
        } else {
            return metadatas[row]
        }
    }

    internal func getSection(metadata: tableMetadata) -> Int {

        let section = self.sections.firstIndex(where: {$0 == getSectionField(metadata: metadata)}) ?? 0
        return section
    }

    internal func getSectionField(metadata: tableMetadata) -> String {

        switch self.groupByField {
        case "name":
            return metadata.name
        default:
            return metadata.name
        }
    }
}
