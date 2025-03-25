//
//  NCCollectionViewDataSource.swift
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
import RealmSwift

class NCCollectionViewDataSource: NSObject {
    private let utilityFileSystem = NCUtilityFileSystem()
    private let utility = NCUtility()
    private let global = NCGlobal.shared
    private var sectionsValue: [String] = []
    private var providers: [NKSearchProvider]?
    private var searchResults: [NKSearchResult]?
    private var metadatas: [tableMetadata] = []
    private var metadatasForSection: [NCMetadataForSection] = []
    private var layoutForView: NCDBLayoutForView?
    private var metadataIndexPath = ThreadSafeDictionary<IndexPath, tableMetadata>()
    private var directoryOnTop: Bool = true

    override init() { super.init() }

    init(metadatas: [tableMetadata],
         layoutForView: NCDBLayoutForView? = nil,
         providers: [NKSearchProvider]? = nil,
         searchResults: [NKSearchResult]? = nil,
         directoryOnTop: Bool = true) {
        super.init()
        removeAll()

        self.metadatas = metadatas
        self.layoutForView = layoutForView
        self.directoryOnTop = directoryOnTop
        /// unified search
        self.providers = providers
        self.searchResults = searchResults

        if let providers, !providers.isEmpty || (layoutForView?.groupBy != "none") {
            createSections()
        }
    }

    // MARK: -

    func removeAll() {
        self.metadatas.removeAll()
        self.metadataIndexPath.removeAll()

        self.metadatasForSection.removeAll()
        self.sectionsValue.removeAll()
        self.providers = nil
        self.searchResults = nil
    }

    func addSection(metadatas: [tableMetadata], searchResult: NKSearchResult?) {
        self.metadatas.append(contentsOf: metadatas)

        if let searchResult = searchResult {
            self.searchResults?.append(searchResult)
        }

        createSections()
    }

    internal func createSections() {
        for metadata in self.metadatas {
            /// skipped livePhoto VIDEO part
            if metadata.isLivePhoto, metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                continue
            }
            let section = NSLocalizedString(self.getSectionValue(metadata: metadata), comment: "")
            if !self.sectionsValue.contains(section) {
                self.sectionsValue.append(section)
            }
        }
        /// Unified search
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
                if section.key == global.appName {
                    self.sectionsValue.insert(section.key, at: 0)
                } else {
                    self.sectionsValue.append(section.key)
                }
            }
        } else {
            /// normal
            let directory = NSLocalizedString("directory", comment: "").lowercased().firstUppercased
            self.sectionsValue = self.sectionsValue.sorted {
                if self.directoryOnTop,
                   $0 == directory {
                    return true
                } else if self.directoryOnTop,
                          $1 == directory {
                    return false
                }
                if let ascending = layoutForView?.ascending,
                    ascending {
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
                                                      layoutForView: self.layoutForView,
                                                      directoryOnTop: self.directoryOnTop)
        metadatasForSection.append(metadataForSection)
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

    func getMetadatas() -> [tableMetadata] {
        return self.metadatas
    }

    func isEmpty() -> Bool {
        return self.metadatas.isEmpty
    }

    func getIndexPathMetadata(ocId: String) -> IndexPath? {
        guard self.sectionsValue.isEmpty else { return nil }
        let validMetadatas = self.metadatas.filter { !$0.isInvalidated }

        if let rowIndex = validMetadatas.firstIndex(where: {$0.ocId == ocId}) {
            return IndexPath(row: rowIndex, section: 0)
        }

        return nil
    }

    func numberOfSections() -> Int {
        guard !self.sectionsValue.isEmpty else { return 1 }

        return self.sectionsValue.count
    }

    func numberOfItemsInSection(_ section: Int) -> Int {
        if self.sectionsValue.isEmpty {
            let validMetadatas = metadatas.filter { !$0.isInvalidated }
            return validMetadatas.count
        }
        guard !self.metadatas.isEmpty,
              let metadataForSection = getMetadataForSection(section)
        else { return 0}

        return metadataForSection.metadatas.count
    }

    func getSectionValueLocalization(indexPath: IndexPath) -> String {
        guard !metadatasForSection.isEmpty, let metadataForSection = self.getMetadataForSection(indexPath.section) else { return ""}

        if let searchResults = self.searchResults, let searchResult = searchResults.filter({ $0.id == metadataForSection.sectionValue}).first {
            return searchResult.name
        }

        return metadataForSection.sectionValue
    }

    func getFooterInformation() -> (directories: Int, files: Int, size: Int64) {
        let validMetadatas = metadatas.filter { !$0.isInvalidated }
        let directories = validMetadatas.filter({ $0.directory == true})
        let files = validMetadatas.filter({ $0.directory == false})
        var size: Int64 = 0

        files.forEach { metadata in
            size += metadata.size
        }

        return (directories.count, files.count, size)
    }

    func getResultMetadata(indexPath: IndexPath) -> tableMetadata? {
        let validMetadatas = metadatas.filter { !$0.isInvalidated }

        if indexPath.row < validMetadatas.count {
            return validMetadatas[indexPath.row]
        }

        return nil
    }

    func getMetadata(indexPath: IndexPath) -> tableMetadata? {
        if !metadatasForSection.isEmpty, indexPath.section < metadatasForSection.count {
            if let metadataForSection = getMetadataForSection(indexPath.section),
               indexPath.row < metadataForSection.metadatas.count,
               !metadataForSection.metadatas[indexPath.row].isInvalidated {
                return tableMetadata(value: metadataForSection.metadatas[indexPath.row])
            }
        } else if indexPath.row < self.metadatas.count {
            if let metadata = metadataIndexPath[indexPath] {
                return metadata
            } else {
                let validMetadatas = self.metadatas.filter { !$0.isInvalidated }
                let metadata = tableMetadata(value: validMetadatas[indexPath.row])
                metadataIndexPath[indexPath] = metadata
                return metadata
            }
        }

        return nil
    }

    func caching(metadatas: [tableMetadata], dataSourceMetadatas: [tableMetadata], completion: @escaping () -> Void) {
        var counter: Int = 0

        DispatchQueue.global().async {
            for metadata in metadatas {
                let metadata = tableMetadata(value: metadata)
                let indexPath = IndexPath(row: counter, section: 0)
                self.metadataIndexPath[indexPath] = tableMetadata(value: metadata)

                /// caching preview
                /// 
                if metadata.isImageOrVideo,
                   NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: self.global.previewExt256) == nil,
                   let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: self.global.previewExt256) {
                    NCImageCache.shared.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: self.global.previewExt256, cost: counter)
                }

                counter += 1
            }

            return completion()
        }
    }

    func removeImageCache() {
        DispatchQueue.global().async {
            for metadata in self.metadatas {
                NCImageCache.shared.removeImageCache(ocIdPlusEtag: metadata.ocId + metadata.etag)
            }
        }
    }

    // MARK: -

    internal func isSameNumbersOfSections(numberOfSections: Int) -> Bool {
        guard !self.metadatasForSection.isEmpty else { return false }
        return numberOfSections == self.numberOfSections()
    }

    internal func getSectionValue(metadata: tableMetadata) -> String {
        switch self.layoutForView?.groupBy {
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
    var layoutForView: NCDBLayoutForView?
    var directoryOnTop: Bool

    private var metadatasSorted: [tableMetadata] = []
    private var metadatasFavoriteDirectory: [tableMetadata] = []
    private var metadatasFavoriteFile: [tableMetadata] = []
    private var metadatasDirectory: [tableMetadata] = []
    private var metadatasFile: [tableMetadata] = []

    public var numDirectory: Int = 0
    public var numFile: Int = 0
    public var totalSize: Int64 = 0

    init(sectionValue: String, metadatas: [tableMetadata], lastSearchResult: NKSearchResult?, layoutForView: NCDBLayoutForView?, directoryOnTop: Bool) {
        self.sectionValue = sectionValue
        self.metadatas = metadatas
        self.lastSearchResult = lastSearchResult
        self.layoutForView = layoutForView
        self.directoryOnTop = directoryOnTop

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
        if let layoutForView = self.layoutForView, layoutForView.sort != "none" && !layoutForView.sort.isEmpty {
            metadatasSorted = metadatas.sorted {
                switch layoutForView.sort {
                case "date":
                    if layoutForView.ascending {
                        return ($0.date as Date) < ($1.date as Date)
                    } else {
                        return ($0.date as Date) > ($1.date as Date)
                    }
                case "size":
                    if layoutForView.ascending {
                        return $0.size < $1.size
                    } else {
                        return $0.size > $1.size
                    }
                default:
                    if layoutForView.ascending {
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

            // skipped livePhoto VIDEO part
            if metadata.isLivePhoto,
               metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
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
            if metadata.favorite {
                if metadata.directory {
                    metadatasFavoriteDirectory.append(metadata)
                } else {
                    metadatasFavoriteFile.append(metadata)
                }
            } else if metadata.directory && self.directoryOnTop {
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
