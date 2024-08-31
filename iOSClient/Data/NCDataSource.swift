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
import NextcloudKit

class NCDataSource: NSObject {
    private var metadatas: [tableMetadata] = []
    private var metadatasForSection: [NCMetadataForSection] = []
    private let utilityFileSystem = NCUtilityFileSystem()
    private let global = NCGlobal.shared

    override init() {
        super.init()
    }

    init(metadatas: [tableMetadata],
         layoutForView: NCDBLayoutForView?,
         providers: [NKSearchProvider]? = nil,
         searchResults: [NKSearchResult]? = nil) {
        super.init()
        self.metadatas = metadatas
    }

    // MARK: -

    func clearDataSource() { }
    func addSection(metadatas: [tableMetadata], searchResult: NKSearchResult?) { }
    func appendMetadatasToSection(_ metadatas: [tableMetadata], metadataForSection: NCMetadataForSection, lastSearchResult: NKSearchResult) { }
    func numberOfSections() -> Int {
       return 1
    }
    func numberOfItemsInSection(_ section: Int) -> Int {
        return metadatas.count
    }
    func getResultsMetadatas() -> [tableMetadata] {
        return metadatas
    }
    func isEmpty() -> Bool {
        return metadatas.isEmpty
    }
    func getResultttMetadata(indexPath: IndexPath) -> tableMetadata? {
        if indexPath.row < metadatas.count {
            return metadatas[indexPath.row]
        }
        return nil
    }
    func getMetadata(indexPath: IndexPath) -> tableMetadata? {
        if indexPath.row < metadatas.count {
            return tableMetadata(value: metadatas[indexPath.row])
        }
        return nil
    }

    func getIndexPathMetadata(ocId: String) -> IndexPath? {
        return nil
    }
    func getSectionValueLocalization(indexPath: IndexPath) -> String {
        return ""
    }

    func getMetadataForSection(_ section: Int) -> NCMetadataForSection? {
       return nil
    }

    func getFooterInformationAllMetadatas() -> (directories: Int, files: Int, size: Int64) {
        var directories: Int = 0
        var files: Int = 0
        var size: Int64 = 0

        /*
        for metadataForSection in metadatasForSection {
            directories += metadataForSection.numDirectory
            files += metadataForSection.numFile
            size += metadataForSection.totalSize
        }
        */
        return (directories, files, size)
    }
}

class NCMetadataForSection: NSObject { }
