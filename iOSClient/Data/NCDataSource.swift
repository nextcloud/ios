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
    var metadatas: [tableMetadata] = []
    var metadatasForSection: [NCMetadataForSection] = []
    var directory: tableDirectory?
    var groupBy: String?
    var layout: String?

    private let utilityFileSystem = NCUtilityFileSystem()
    private var sectionsValue: [String] = []
    private var providers: [NKSearchProvider]?
    private var searchResults: [NKSearchResult]?

    private var ascending: Bool = true
    private var sort: String = ""
    private var directoryOnTop: Bool = true
    private var favoriteOnTop: Bool = true

    override init() {
        super.init()
    }

    init(metadatas: [tableMetadata],
         account: String,
         directory: tableDirectory? = nil,
         layoutForView: NCDBLayoutForView?,
         favoriteOnTop: Bool = true,
         providers: [NKSearchProvider]? = nil,
         searchResults: [NKSearchResult]? = nil) {
        super.init()

        self.metadatas = metadatas.filter({
            !(NCGlobal.shared.includeHiddenFiles.contains($0.fileNameView) || $0.isTransferInForeground)
        })
        self.directory = directory
        self.sort = layoutForView?.sort ?? "none"
        self.ascending = layoutForView?.ascending ?? false
        self.directoryOnTop = layoutForView?.directoryOnTop ?? true
        self.favoriteOnTop = favoriteOnTop
        self.groupBy = layoutForView?.groupBy ?? "none"
        self.layout = layoutForView?.layout
        // unified search
        self.providers = providers
        self.searchResults = searchResults

        createSections()
    }

    // MARK: -

    func clearDataSource() {
        self.metadatas.removeAll()
        self.metadatasForSection.removeAll()
        self.directory = nil
        self.sectionsValue.removeAll()
        self.providers = nil
        self.searchResults = nil
    }

    func clearDirectory() {
        self.directory = nil
    }

    func changeGroupByField(_ groupBy: String) {
        self.groupBy = groupBy
        print("DATASOURCE: set group by filed " + groupBy)
        self.metadatasForSection.removeAll()
        self.sectionsValue.removeAll()
        print("DATASOURCE: remove  all sections")

        createSections()
    }

    func addSection(metadatas: [tableMetadata], searchResult: NKSearchResult?) {
        self.metadatas.append(contentsOf: metadatas)

        if let searchResult = searchResult {
            self.searchResults?.append(searchResult)
        }

        createSections()
    }

    internal func createSections() {
        // get all Section
        for metadata in self.metadatas {
            // skipped livePhoto VIDEO part
            if metadata.isLivePhoto && metadata.classFile == NKCommon.TypeClassFile.video.rawValue && metadata.status <= NCGlobal.shared.metadataStatusNormal {
                continue
            }
            let section = NSLocalizedString(self.getSectionValue(metadata: metadata), comment: "")
            if !self.sectionsValue.contains(section) {
                self.sectionsValue.append(section)
            }
            // image Cache
            if (layout == NCGlobal.shared.layoutPhotoRatio || layout == NCGlobal.shared.layoutPhotoSquare),
               (metadata.isVideo || metadata.isImage),
               NCImageCache.shared.getPreviewImageCache(ocId: metadata.ocId, etag: metadata.etag) == nil,
               let image = UIImage(contentsOfFile: self.utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)) {
                NCImageCache.shared.addPreviewImageCache(metadata: metadata, image: image)
            }
        }
        // Unified search
        if let providers = self.providers, !providers.isEmpty {
            let sectionsDictionary = ThreadSafeDictionary<String, Int>()
            for section in self.sectionsValue {
                if let provider = providers.filter({ $0.id == section}).first {
                    sectionsDictionary[section] = provider.order
                }
            }
            self.sectionsValue.removeAll()
            let sectionsDictionarySorted = sectionsDictionary.sorted(by: {$0.value < $1.value })
            for section in sectionsDictionarySorted {
                if section.key == NCGlobal.shared.appName {
                    self.sectionsValue.insert(section.key, at: 0)
                } else {
                    self.sectionsValue.append(section.key)
                }
            }
        } else {
            // normal
            let directory = NSLocalizedString("directory", comment: "").lowercased().firstUppercased
            self.sectionsValue = self.sectionsValue.sorted {
                if directoryOnTop && $0 == directory {
                    return true
                } else if directoryOnTop && $1 == directory {
                    return false
                }
                if self.ascending {
                    return $0 < $1
                } else {
                    return $0 > $1
                }
            }
        }

        for sectionValue in self.sectionsValue {
            if !existsMetadataForSection(sectionValue: sectionValue) {
                print("DATASOURCE: create metadata for section: " + sectionValue)
                createMetadataForSection(sectionValue: sectionValue)
            }
        }
    }

    internal func createMetadataForSection(sectionValue: String) {
        var searchResult: NKSearchResult?
        if let providers = self.providers, !providers.isEmpty, let searchResults = self.searchResults {
            searchResult = searchResults.filter({ $0.id == sectionValue}).first
        }
        let metadatas = self.metadatas.filter({ getSectionValue(metadata: $0) == sectionValue})
        let metadataForSection = NCMetadataForSection(sectionValue: sectionValue,
                                                      metadatas: metadatas,
                                                      lastSearchResult: searchResult,
                                                      sort: self.sort,
                                                      ascending: self.ascending,
                                                      directoryOnTop: self.directoryOnTop,
                                                      favoriteOnTop: self.favoriteOnTop)
        metadatasForSection.append(metadataForSection)
    }

    func getMetadataSourceForAllSections() -> [tableMetadata] {
        var metadatas: [tableMetadata] = []

        for section in metadatasForSection {
            metadatas.append(contentsOf: section.metadatas)
        }
        return metadatas
    }

    // MARK: -

    func appendMetadatasToSection(_ metadatas: [tableMetadata], metadataForSection: NCMetadataForSection, lastSearchResult: NKSearchResult) {
        guard let sectionIndex = getSectionIndex(metadataForSection.sectionValue) else { return }
        var indexPaths: [IndexPath] = []

        self.metadatas.append(contentsOf: metadatas)
        metadataForSection.metadatas.append(contentsOf: metadatas)
        metadataForSection.lastSearchResult = lastSearchResult
        metadataForSection.createMetadatas()

        for metadata in metadatas {
            if let rowIndex = metadataForSection.metadatas.firstIndex(where: {$0.ocId == metadata.ocId}) {
                indexPaths.append(IndexPath(row: rowIndex, section: sectionIndex))
            }
        }
    }

    // MARK: -

    func getIndexPathMetadata(ocId: String) -> (indexPath: IndexPath?, metadataForSection: NCMetadataForSection?) {
        guard let metadata = self.metadatas.filter({ $0.ocId == ocId}).first else { return (nil, nil) }
        let sectionValue = getSectionValue(metadata: metadata)
        guard let sectionIndex = getSectionIndex(sectionValue), let metadataForSection = getMetadataForSection(sectionValue), let rowIndex = metadataForSection.metadatas.firstIndex(where: {$0.ocId == ocId}) else { return (nil, nil) }
        return (IndexPath(row: rowIndex, section: sectionIndex), metadataForSection)
    }

    func numberOfSections() -> Int {
        guard !self.sectionsValue.isEmpty else { return 1 }
        return self.sectionsValue.count
    }

    func numberOfItemsInSection(_ section: Int) -> Int {
        guard !self.sectionsValue.isEmpty && !self.metadatas.isEmpty, let metadataForSection = getMetadataForSection(section) else { return 0}
        return metadataForSection.metadatas.count
    }

    func cellForItemAt(indexPath: IndexPath) -> tableMetadata? {
        guard !metadatasForSection.isEmpty && indexPath.section < metadatasForSection.count, let metadataForSection = getMetadataForSection(indexPath.section), indexPath.row < metadataForSection.metadatas.count else { return nil }
        return metadataForSection.metadatas[indexPath.row]
    }

    func getSectionValueLocalization(indexPath: IndexPath) -> String {
        guard !metadatasForSection.isEmpty, let metadataForSection = self.getMetadataForSection(indexPath.section) else { return ""}
        if let searchResults = self.searchResults, let searchResult = searchResults.filter({ $0.id == metadataForSection.sectionValue}).first {
            return searchResult.name
        }
        return metadataForSection.sectionValue
    }

    func getFooterInformationAllMetadatas() -> (directories: Int, files: Int, size: Int64) {
        var directories: Int = 0
        var files: Int = 0
        var size: Int64 = 0

        for metadataForSection in metadatasForSection {
            directories += metadataForSection.numDirectory
            files += metadataForSection.numFile
            size += metadataForSection.totalSize
        }
        return (directories, files, size)
    }

    // MARK: -

    internal func isSameNumbersOfSections(numberOfSections: Int) -> Bool {
        guard !self.metadatasForSection.isEmpty else { return false }
        return numberOfSections == self.numberOfSections()
    }

    internal func getSectionValue(metadata: tableMetadata) -> String {
        switch self.groupBy {
        case "name", "none":
            return NSLocalizedString(metadata.name, comment: "")
        case "classFile":
            return NSLocalizedString(metadata.classFile, comment: "").lowercased().firstUppercased
        default:
            return NSLocalizedString(metadata.name, comment: "")
        }
    }

    internal func getIndexMetadatasForSection(_ sectionValue: String) -> Int? {
        return self.metadatasForSection.firstIndex(where: {$0.sectionValue == sectionValue })
    }

    internal func getSectionIndex(_ sectionValue: String) -> Int? {
         return self.sectionsValue.firstIndex(where: {$0 == sectionValue })
    }

    internal func existsMetadataForSection(sectionValue: String) -> Bool {
        return !self.metadatasForSection.filter({ $0.sectionValue == sectionValue }).isEmpty
    }

    internal func getMetadataForSection(_ section: Int) -> NCMetadataForSection? {
        guard section < sectionsValue.count, let metadataForSection = self.metadatasForSection.filter({ $0.sectionValue == sectionsValue[section]}).first else { return nil }
        return metadataForSection
    }

    internal func getMetadataForSection(_ sectionValue: String) -> NCMetadataForSection? {
        guard let metadataForSection = self.metadatasForSection.filter({ $0.sectionValue == sectionValue }).first else { return nil }
        return metadataForSection
    }
}

// MARK: -

class NCMetadataForSection: NSObject {
    var sectionValue: String
    var metadatas: [tableMetadata]
    var lastSearchResult: NKSearchResult?
    var unifiedSearchInProgress: Bool = false

    private var sort: String
    private var ascending: Bool
    private var directoryOnTop: Bool
    private var favoriteOnTop: Bool

    private var metadatasSorted: [tableMetadata] = []
    private var metadatasFavoriteDirectory: [tableMetadata] = []
    private var metadatasFavoriteFile: [tableMetadata] = []
    private var metadatasDirectory: [tableMetadata] = []
    private var metadatasFile: [tableMetadata] = []

    public var numDirectory: Int = 0
    public var numFile: Int = 0
    public var totalSize: Int64 = 0

    init(sectionValue: String, metadatas: [tableMetadata], lastSearchResult: NKSearchResult?, sort: String, ascending: Bool, directoryOnTop: Bool, favoriteOnTop: Bool) {

        self.sectionValue = sectionValue
        self.metadatas = metadatas
        self.lastSearchResult = lastSearchResult
        self.sort = sort
        self.ascending = ascending
        self.directoryOnTop = directoryOnTop
        self.favoriteOnTop = favoriteOnTop

        super.init()

        createMetadatas()
    }

    func createMetadatas() {
        // Clear
        //
        metadatasSorted.removeAll()
        metadatasFavoriteDirectory.removeAll()
        metadatasFavoriteFile.removeAll()
        metadatasDirectory.removeAll()
        metadatasFile.removeAll()

        numDirectory = 0
        numFile = 0
        totalSize = 0

        var ocIds: [String] = []
        let metadataInSession = metadatas.filter({ !$0.session.isEmpty })

        // Metadata order
        //
        if sort != "none" && !sort.isEmpty {
            metadatasSorted = metadatas.sorted {
                switch sort {
                case "date":
                    if ascending {
                        return ($0.date as Date) < ($1.date as Date)
                    } else {
                        return ($0.date as Date) > ($1.date as Date)
                    }
                case "size":
                    if ascending {
                        return $0.size < $1.size
                    } else {
                        return $0.size > $1.size
                    }
                default:
                    if ascending {
                        return $0.fileNameView.lowercased() < $1.fileNameView.lowercased()
                    } else {
                        return $0.fileNameView.lowercased() > $1.fileNameView.lowercased()
                    }
                }
            }
        } else {
            metadatasSorted = metadatas
        }

        // Initialize datasource
        //
        for metadata in metadatasSorted {

            // skipped the root file
            if metadata.fileName == "." || metadata.serverUrl == ".." {
                continue
            }

            // skipped livePhoto
            if metadata.isLivePhoto && metadata.classFile == NKCommon.TypeClassFile.video.rawValue && metadata.status <= NCGlobal.shared.metadataStatusNormal {
                continue
            }

            // Upload [REPLACE] skip
            if metadata.session.isEmpty && !metadataInSession.filter({ $0.fileNameView == metadata.fileNameView }).isEmpty {
                continue
            }

            // Upload [REPLACE] skip
            if metadata.session.isEmpty && !metadataInSession.filter({ $0.fileNameView == metadata.fileNameView }).isEmpty {
                continue
            }

            // Organized the metadata
            if metadata.favorite && favoriteOnTop {
                if metadata.directory {
                    metadatasFavoriteDirectory.append(metadata)
                } else {
                    metadatasFavoriteFile.append(metadata)
                }
            } else if  metadata.directory && directoryOnTop {
                metadatasDirectory.append(metadata)
            } else {
                metadatasFile.append(metadata)
            }

            if metadata.directory {
                ocIds.append(metadata.ocId)
                numDirectory += 1
            } else {
                numFile += 1
                totalSize += metadata.size
            }
        }

        metadatas.removeAll()

        // Struct view : favorite dir -> favorite file -> directory -> files
        metadatas += metadatasFavoriteDirectory
        metadatas += metadatasFavoriteFile
        metadatas += metadatasDirectory
        metadatas += metadatasFile
    }
}
