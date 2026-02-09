// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

class NCCollectionViewDataSource: NSObject {
    private let utilityFileSystem = NCUtilityFileSystem()
    private let utility = NCUtility()
    private let global = NCGlobal.shared
    private let database = NCManageDatabase.shared

    private var sections: [String] = []
    private var isSections: Bool = false
    private var searchResults: [NKSearchResult]?
    private var metadatas: [tableMetadata] = []
    private var metadatasForSection: [NCMetadataForSection] = []
    private var layoutForView: NCDBLayoutForView?
    private var directoryOnTop: Bool = true
    private var favoriteOnTop: Bool = true
    private var hasGetServerData: Bool = true

    override init() { super.init() }

    init(metadatas: [tableMetadata],
         layoutForView: NCDBLayoutForView? = nil,
         isSections: Bool = false,
         searchResults: [NKSearchResult]? = nil,
         account: String? = nil) {
        super.init()
        removeAll()

        self.metadatas = metadatas
        self.layoutForView = layoutForView
        if let account {
            self.directoryOnTop = NCPreferences().getDirectoryOnTop(account: account)
            self.favoriteOnTop = NCPreferences().getFavoriteOnTop(account: account)
        }
        // is Sections
        self.isSections = isSections
        // unified search
        self.searchResults = searchResults

        if isSections || (layoutForView?.groupBy != "none") {
            createSections()
        }
    }

    // MARK: -

    func getGetServerData() -> Bool {
        return hasGetServerData
    }

    func setGetServerData(_ state: Bool) {
        hasGetServerData = state
    }

    // MARK: -

    func removeAll() {
        self.metadatas.removeAll()
        self.metadatasForSection.removeAll()
        self.sections.removeAll()
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
        for metadata in metadatas {
            if metadata.isLivePhoto,
               metadata.classFile == NKTypeClassFile.video.rawValue {
                continue
            }

            if !sections.contains(metadata.section) {
                sections.append(metadata.section)
            }
        }
        // Section order
        if isSections {
            /*
            sectionsValue = sectionsValue.sorted {
                (orderMap[$0] ?? 0) < (orderMap[$1] ?? 0)
            }
            */
        } else {
            // normal
            let favorite = NSLocalizedString("favorite", comment: "").lowercased().firstUppercased
            let directory = NSLocalizedString("directory", comment: "").lowercased().firstUppercased

            self.sections = self.sections.sorted { lhs, rhs in
                // 1. favorite on top
                if favoriteOnTop {
                    if lhs == favorite && rhs != favorite {
                        return true
                    }
                    if rhs == favorite && lhs != favorite {
                        return false
                    }
                }

                // 2. directory on top
                if directoryOnTop {
                    if lhs == directory && rhs != directory {
                        return true
                    }
                    if rhs == directory && lhs != directory {
                        return false
                    }
                }

                // 3. alphabetical
                let ascending = layoutForView?.ascending ?? true
                return ascending ? lhs < rhs : lhs > rhs
            }
        }

        for section in self.sections {
            if !existsMetadataForSection(section: section) {
                print("DATASOURCE: create metadata for section: " + section)
                createMetadataForSection(section: section)
            }
        }
    }

    internal func createMetadataForSection(section: String) {
        var searchResult: NKSearchResult?
        if isSections, let searchResults = self.searchResults {
            searchResult = searchResults.filter({ $0.id == section}).first
        }
        let metadatas = self.metadatas.filter({ $0.section == section})
        let metadataForSection = NCMetadataForSection(section: section,
                                                      metadatas: metadatas,
                                                      lastSearchResult: searchResult,
                                                      layoutForView: self.layoutForView,
                                                      favoriteOnTop: self.favoriteOnTop,
                                                      directoryOnTop: self.directoryOnTop)
        metadatasForSection.append(metadataForSection)
    }

    // MARK: -

    func appendMetadatasToSection(_ metadatas: [tableMetadata], metadataForSection: NCMetadataForSection, lastSearchResult: NKSearchResult) {
        guard let sectionIndex = getSectionIndex(metadataForSection.section)
        else {
            return
        }
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
        guard self.sections.isEmpty else {
            return nil
        }

        if let rowIndex = metadatas.firstIndex(where: {$0.ocId == ocId}) {
            return IndexPath(row: rowIndex, section: 0)
        }

        return nil
    }

    func numberOfSections() -> Int {
        guard !self.sections.isEmpty else {
            return 1
        }

        return self.sections.count
    }

    func numberOfItemsInSection(_ section: Int) -> Int {
        if self.sections.isEmpty {
            return metadatas.count
        }

        guard !self.metadatas.isEmpty,
              let metadataForSection = getMetadataForSection(section) else {
            return 0
        }

        return metadataForSection.metadatas.count
    }

    func getSectionValueLocalization(indexPath: IndexPath) -> String {
        guard !metadatasForSection.isEmpty,
              let metadataForSection = self.getMetadataForSection(indexPath.section)
        else {
            return ""
        }

        if let searchResults = self.searchResults,
           let searchResult = searchResults.filter({ $0.id == metadataForSection.section}).first {
            return searchResult.name
        }

        return metadataForSection.section
    }

    func getFooterInformation() -> (directories: Int, files: Int, size: Int64) {
        let directories = metadatas.filter({ $0.directory == true})
        let files = metadatas.filter({ $0.directory == false})
        var size: Int64 = 0

        files.forEach { metadata in
            size += metadata.size
        }

        return (directories.count, files.count, size)
    }

    func getResultMetadata(indexPath: IndexPath) -> tableMetadata? {
        if indexPath.row < metadatas.count {
            return metadatas[indexPath.row]
        }

        return nil
    }

    func getMetadata(indexPath: IndexPath) -> tableMetadata? {
        if !metadatasForSection.isEmpty, indexPath.section < metadatasForSection.count {
            if let metadataForSection = getMetadataForSection(indexPath.section),
               indexPath.row < metadataForSection.metadatas.count {
                return metadataForSection.metadatas[indexPath.row].detachedCopy()
            }
        } else if indexPath.row < self.metadatas.count {
            let metadata = self.metadatas[indexPath.row]
            return metadata
        }

        return nil
    }

    // MARK: -

    internal func isSameNumbersOfSections(numberOfSections: Int) -> Bool {
        guard !self.metadatasForSection.isEmpty else { return false }
        return numberOfSections == self.numberOfSections()
    }

    internal func getIndexMetadatasForSection(_ section: String) -> Int? {
        return self.metadatasForSection.firstIndex(where: {$0.section == section })
    }

    internal func getSectionIndex(_ section: String) -> Int? {
         return self.sections.firstIndex(where: {$0 == section })
    }

    internal func existsMetadataForSection(section: String) -> Bool {
        return !self.metadatasForSection.filter({ $0.section == section }).isEmpty
    }

    internal func getMetadataForSection(_ section: Int) -> NCMetadataForSection? {
        guard section < sections.count, let metadataForSection = self.metadatasForSection.filter({ $0.section == sections[section]}).first else { return nil }
        return metadataForSection
    }

    internal func getMetadataForSection(_ section: String) -> NCMetadataForSection? {
        guard let metadataForSection = self.metadatasForSection.filter({ $0.section == section }).first else { return nil }
        return metadataForSection
    }
}

// MARK: -

class NCMetadataForSection: NSObject {
    var section: String
    var metadatas: [tableMetadata]
    var lastSearchResult: NKSearchResult?
    var unifiedSearchInProgress: Bool = false
    var layoutForView: NCDBLayoutForView?
    var directoryOnTop: Bool
    var favoriteOnTop: Bool

    private var metadatasSorted: [tableMetadata] = []
    private var metadatasFavoriteDirectory: [tableMetadata] = []
    private var metadatasFavoriteFile: [tableMetadata] = []
    private var metadatasDirectory: [tableMetadata] = []
    private var metadatasFile: [tableMetadata] = []

    public var numDirectory: Int = 0
    public var numFile: Int = 0
    public var totalSize: Int64 = 0

    init(section: String, metadatas: [tableMetadata], lastSearchResult: NKSearchResult?, layoutForView: NCDBLayoutForView?, favoriteOnTop: Bool, directoryOnTop: Bool) {
        self.section = section
        self.metadatas = metadatas
        self.lastSearchResult = lastSearchResult
        self.layoutForView = layoutForView
        self.favoriteOnTop = favoriteOnTop
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
            if metadata.fileName == NextcloudKit.shared.nkCommonInstance.rootFileName {
                continue
            }

            // skipped livePhoto VIDEO part
            if metadata.isLivePhoto,
               metadata.classFile == NKTypeClassFile.video.rawValue {
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

            // Organize the metadata based on favoriteOnTop and directoryOnTop
            if favoriteOnTop && metadata.favorite {
                if metadata.directory {
                    metadatasFavoriteDirectory.append(metadata)
                } else {
                    metadatasFavoriteFile.append(metadata)
                }
            } else if directoryOnTop && metadata.directory {
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
