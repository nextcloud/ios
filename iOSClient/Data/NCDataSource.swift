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
    var groupByField: String = ""

    private var sectionsValue: [String] = []
    private var providers: [NKSearchProvider]?
    private var searchResults: [NKSearchResult]?
    private var localFiles: [tableLocalFile] = []

    private var ascending: Bool = true
    private var sort: String = ""
    private var directoryOnTop: Bool = true
    private var favoriteOnTop: Bool = true
    private var filterLivePhoto: Bool = true

    override init() {
        super.init()
    }

    init(metadatas: [tableMetadata], account: String, directory: tableDirectory? = nil, sort: String? = "none", ascending: Bool? = false, directoryOnTop: Bool? = true, favoriteOnTop: Bool? = true, filterLivePhoto: Bool? = true, groupByField: String = "name", providers: [NKSearchProvider]? = nil, searchResults: [NKSearchResult]? = nil) {
        super.init()

        self.metadatas = metadatas.filter({
            !NCGlobal.shared.includeHiddenFiles.contains($0.fileNameView)
        })
        self.directory = directory
        self.localFiles = NCManageDatabase.shared.getTableLocalFile(account: account)
        self.sort = sort ?? "none"
        self.ascending = ascending ?? false
        self.directoryOnTop = directoryOnTop ?? true
        self.favoriteOnTop = favoriteOnTop ?? true
        self.filterLivePhoto = filterLivePhoto ?? true
        self.groupByField = groupByField
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
        self.localFiles.removeAll()
    }

    func clearDirectory() {

        self.directory = nil
    }

    func changeGroupByField(_ groupByField: String) {

        self.groupByField = groupByField
        print("DATASOURCE: set group by filed " + groupByField)
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
            // skipped livePhoto
            if filterLivePhoto && metadata.livePhoto && (metadata.fileNameView as NSString).pathExtension.lowercased() == "mov" {
                continue
            }
            let section = NSLocalizedString(self.getSectionValue(metadata: metadata), comment: "")
            if !self.sectionsValue.contains(section) {
                self.sectionsValue.append(section)
            }
        }

        // Unified search
        if let providers = self.providers, !providers.isEmpty {
            let sectionsDictionary = ThreadSafeDictionary<String,Int>()
            for section in self.sectionsValue {
                if let provider = providers.filter({ $0.id == section}).first {
                    sectionsDictionary[section] = provider.order
                }
            }
            self.sectionsValue.removeAll()
            let sectionsDictionarySorted = sectionsDictionary.sorted(by: { $0.value < $1.value } )
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
        let metadataForSection = NCMetadataForSection.init(sectionValue: sectionValue,
                                                            metadatas: metadatas,
                                                            localFiles: self.localFiles,
                                                            lastSearchResult: searchResult,
                                                            sort: self.sort,
                                                            ascending: self.ascending,
                                                            directoryOnTop: self.directoryOnTop,
                                                            favoriteOnTop: self.favoriteOnTop,
                                                            filterLivePhoto: self.filterLivePhoto)
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

    @discardableResult
    func appendMetadatasToSection(_ metadatas: [tableMetadata], metadataForSection: NCMetadataForSection, lastSearchResult: NKSearchResult) -> [IndexPath] {
        
        guard let sectionIndex =  getSectionIndex(metadataForSection.sectionValue) else { return [] }
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

        return indexPaths
    }

    @discardableResult
    func addMetadata(_ metadata: tableMetadata) -> (indexPath: IndexPath?, sameSections: Bool) {

        let numberOfSections = self.numberOfSections()
        let sectionValue = getSectionValue(metadata: metadata)

        // ADD metadatasSource
        if let rowIndex = self.metadatas.firstIndex(where: {$0.fileNameView == metadata.fileNameView || $0.ocId == metadata.ocId}) {
            self.metadatas[rowIndex] = metadata
        } else {
            self.metadatas.append(metadata)
        }

        // ADD metadataForSection
        if let sectionIndex = getSectionIndex(sectionValue), let metadataForSection = getMetadataForSection(sectionIndex) {
            if let rowIndex = metadataForSection.metadatas.firstIndex(where: {$0.fileNameView == metadata.fileNameView || $0.ocId == metadata.ocId}) {
                metadataForSection.metadatas[rowIndex] = metadata
                return (IndexPath(row: rowIndex, section: sectionIndex), self.isSameNumbersOfSections(numberOfSections: numberOfSections))
            } else {
                metadataForSection.metadatas.append(metadata)
                metadataForSection.createMetadatas()
                if let rowIndex = metadataForSection.metadatas.firstIndex(where: {$0.ocId == metadata.ocId}) {
                    return (IndexPath(row: rowIndex, section: sectionIndex), self.isSameNumbersOfSections(numberOfSections: numberOfSections))
                }
                return (nil, self.isSameNumbersOfSections(numberOfSections: numberOfSections))
            }
        } else {
            // NEW section
            createSections()
            // get IndexPath of new section
            if let sectionIndex = getSectionIndex(sectionValue), let metadataForSection = getMetadataForSection(sectionIndex) {
                if let rowIndex = metadataForSection.metadatas.firstIndex(where: {$0.fileNameView == metadata.fileNameView || $0.ocId == metadata.ocId}) {
                    return (IndexPath(row: rowIndex, section: sectionIndex), self.isSameNumbersOfSections(numberOfSections: numberOfSections))
                }
            }
        }

        return (nil, self.isSameNumbersOfSections(numberOfSections: numberOfSections))
    }

    func deleteMetadata(ocId: String) -> (indexPath: IndexPath?, sameSections: Bool) {

        let numberOfSections = self.numberOfSections()
        var indexPathReturn: IndexPath?
        var sectionValue = ""

        // DELETE metadataForSection (IMPORTANT FIRST)
        let (indexPath, metadataForSection) = self.getIndexPathMetadata(ocId: ocId)
        if let indexPath = indexPath, let metadataForSection = metadataForSection, indexPath.row < metadataForSection.metadatas.count {
            metadataForSection.metadatas.remove(at: indexPath.row)
            if metadataForSection.metadatas.count == 0 {
                // REMOVE sectionsValue / metadatasForSection
                sectionValue = metadataForSection.sectionValue
                if let sectionIndex = getSectionIndex(sectionValue) {
                    self.sectionsValue.remove(at: sectionIndex)
                }
                if let index = getIndexMetadatasForSection(sectionValue) {
                    self.metadatasForSection.remove(at: index)
                }
            } else {
                metadataForSection.createMetadatas()
            }
            indexPathReturn = indexPath
        } else { return (nil, false) }

        // DELETE metadatasSource (IMPORTANT LAST)
        if let rowIndex = self.metadatas.firstIndex(where: {$0.ocId == ocId}) {
            self.metadatas.remove(at: rowIndex)
        }

        return (indexPathReturn, self.isSameNumbersOfSections(numberOfSections: numberOfSections))
    }

    @discardableResult
    func reloadMetadata(ocId: String, ocIdTemp: String? = nil) -> (indexPath: IndexPath?, sameSections: Bool) {

        let numberOfSections = self.numberOfSections()
        var ocIdSearch = ocId

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return (nil, self.isSameNumbersOfSections(numberOfSections: numberOfSections)) }

        if let ocIdTemp = ocIdTemp {
            ocIdSearch = ocIdTemp
        }

        // UPDATE metadataForSection (IMPORTANT FIRST)
        let (indexPath, metadataForSection) = self.getIndexPathMetadata(ocId: ocIdSearch)
        if let indexPath = indexPath, let metadataForSection = metadataForSection {
            metadataForSection.metadatas[indexPath.row] = metadata
            metadataForSection.createMetadatas()
        }

        // UPDATE metadatasSource (IMPORTANT LAST)
        if let rowIndex = self.metadatas.firstIndex(where: {$0.ocId == ocIdSearch}) {
            self.metadatas[rowIndex] = metadata
        }

        let result = self.getIndexPathMetadata(ocId: ocId)
        return (result.indexPath, self.isSameNumbersOfSections(numberOfSections: numberOfSections))
    }

    // MARK: -

    func getIndexPathMetadata(ocId: String) -> (indexPath: IndexPath?, metadataForSection: NCMetadataForSection?) {
        guard let metadata = self.metadatas.filter({ $0.ocId == ocId}).first else { return (nil, nil) }
        let sectionValue = getSectionValue(metadata: metadata)
        guard let sectionIndex = getSectionIndex(sectionValue), let metadataForSection = getMetadataForSection(sectionValue), let rowIndex = metadataForSection.metadatas.firstIndex(where: {$0.ocId == ocId}) else { return (nil, nil) }
        return (IndexPath(row: rowIndex, section: sectionIndex), metadataForSection)
    }

    func isSameNumbersOfSections(numberOfSections: Int) -> Bool {
        guard self.metadatasForSection.count > 0 else { return false }
        return numberOfSections == self.numberOfSections()
    }

    func numberOfSections() -> Int {
        guard self.sectionsValue.count > 0 else { return 1 }
        return self.sectionsValue.count
    }
    
    func numberOfItemsInSection(_ section: Int) -> Int {
        guard self.sectionsValue.count > 0 && self.metadatas.count > 0, let metadataForSection = getMetadataForSection(section) else { return 0}
        return metadataForSection.metadatas.count
    }

    func cellForItemAt(indexPath: IndexPath) -> tableMetadata? {
        guard metadatasForSection.count > 0 && indexPath.section < metadatasForSection.count, let metadataForSection = getMetadataForSection(indexPath.section), indexPath.row < metadataForSection.metadatas.count else { return nil }
        return metadataForSection.metadatas[indexPath.row]
    }

    func getSectionValue(indexPath: IndexPath) -> String {
        guard metadatasForSection.count > 0 , let metadataForSection = self.getMetadataForSection(indexPath.section) else { return ""}
        return metadataForSection.sectionValue
    }

    func getSectionValueLocalization(indexPath: IndexPath) -> String {
        guard metadatasForSection.count > 0 , let metadataForSection = self.getMetadataForSection(indexPath.section) else { return ""}
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

    internal func getSectionValue(metadata: tableMetadata) -> String {

        switch self.groupByField {
        case "name":
            return NSLocalizedString(metadata.name, comment: "")
        case "classFile":
            return NSLocalizedString(metadata.classFile, comment: "").lowercased().firstUppercased
        default:
            return NSLocalizedString(metadata.classFile, comment: "")
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
    var localFiles: [tableLocalFile]
    var lastSearchResult: NKSearchResult?
    var unifiedSearchInProgress: Bool = false

    private var sort : String
    private var ascending: Bool
    private var directoryOnTop: Bool
    private var favoriteOnTop: Bool
    private var filterLivePhoto: Bool

    private var metadatasSorted: [tableMetadata] = []
    private var metadatasFavoriteDirectory: [tableMetadata] = []
    private var metadatasFavoriteFile: [tableMetadata] = []
    private var metadatasDirectory: [tableMetadata] = []
    private var metadatasFile: [tableMetadata] = []

    public var numDirectory: Int = 0
    public var numFile: Int = 0
    public var totalSize: Int64 = 0
    public var metadataOffLine: [String] = []
    public var directories: [tableDirectory]?

    init(sectionValue: String, metadatas: [tableMetadata], localFiles: [tableLocalFile], lastSearchResult: NKSearchResult?, sort: String, ascending: Bool, directoryOnTop: Bool, favoriteOnTop: Bool, filterLivePhoto: Bool) {

        self.sectionValue = sectionValue
        self.metadatas = metadatas
        self.localFiles = localFiles
        self.lastSearchResult = lastSearchResult
        self.sort = sort
        self.ascending = ascending
        self.directoryOnTop = directoryOnTop
        self.favoriteOnTop = favoriteOnTop
        self.filterLivePhoto = filterLivePhoto

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
        metadataOffLine.removeAll()

        numDirectory = 0
        numFile = 0
        totalSize = 0

        var ocIds: [String] = []
        let metadataInSession = metadatas.filter({ !$0.session.isEmpty })

        // Metadata order
        //
        if sort != "none" && sort != "" {
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
            if filterLivePhoto && metadata.livePhoto && (metadata.fileNameView as NSString).pathExtension.lowercased() == "mov" {
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

            //Info
            if metadata.directory {
                ocIds.append(metadata.ocId)
                numDirectory += 1
            } else {
                numFile += 1
                totalSize += metadata.size
            }
        }

        directories = NCManageDatabase.shared.getTablesDirectory(predicate: NSPredicate(format: "ocId IN %@", ocIds), sorted: "serverUrl", ascending: true)

        metadatas.removeAll()

        // Struct view : favorite dir -> favorite file -> directory -> files
        metadatas += metadatasFavoriteDirectory
        metadatas += metadatasFavoriteFile
        metadatas += metadatasDirectory
        metadatas += metadatasFile
    }
}
