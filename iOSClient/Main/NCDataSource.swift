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

import Foundation

@objc class NCDataSource: NSObject {
    
    @objc var metadatas: [tableMetadata] = []

    private var sort: String = ""
    private var ascending: Bool = true
    private var directoryOnTop: Bool = true
    private var filterLivePhoto: Bool = true
    
    override init() {
        super.init()
    }
    
    @objc init(metadatasSource: [tableMetadata], sort: String, ascending: Bool, directoryOnTop: Bool, filterLivePhoto: Bool) {
        super.init()
        
        self.sort = sort
        self.ascending = ascending
        self.directoryOnTop = directoryOnTop
        self.filterLivePhoto = filterLivePhoto
        
        createMetadatas(metadatasSource: metadatasSource)
    }
    
    // MARK: -
    
    private func createMetadatas(metadatasSource: [tableMetadata]) {
        
        var metadatasFavorite: [tableMetadata] = []
        var metadatasTemp: [tableMetadata] = []
        var numDirectory: Int = 0
        var numDirectoryFavorite:Int = 0

        /*
        Metadata order
        */
        
        let metadatasSourceSorted = metadatasSource.sorted { (obj1:tableMetadata, obj2:tableMetadata) -> Bool in
            if sort == "date" {
                if ascending {
                    return obj1.date.compare(obj2.date as Date) == ComparisonResult.orderedAscending
                } else {
                    return obj1.date.compare(obj2.date as Date) == ComparisonResult.orderedDescending
                }
            } else if sort == "sessionTaskIdentifier" {
                if ascending {
                    return obj1.sessionTaskIdentifier > obj2.sessionTaskIdentifier
                } else {
                    return obj1.sessionTaskIdentifier < obj2.sessionTaskIdentifier
                }
            } else if sort == "size" {
                if ascending {
                    return obj1.size > obj2.size
                } else {
                    return obj1.size < obj2.size
                }
            } else {
                let range = Range(NSMakeRange(0, obj1.fileNameView.count), in: obj1.fileNameView)
                if ascending {
                    return obj1.fileNameView.compare(obj2.fileNameView, options: .caseInsensitive, range: range, locale: .current) == ComparisonResult.orderedAscending
                } else {
                    return obj1.fileNameView.compare(obj2.fileNameView, options: .caseInsensitive, range: range, locale: .current) == ComparisonResult.orderedDescending
                }
            }
        }
        
        /*
        Initialize datasource
        */
        
        for metadata in metadatasSourceSorted {
            
            // skipped livePhoto
            if metadata.ext == "mov" && metadata.livePhoto && filterLivePhoto {
                continue
            }
            
            if metadata.directory && directoryOnTop {
                if metadata.favorite {
                    metadatasTemp.insert(metadata, at: numDirectoryFavorite)
                    numDirectoryFavorite += 1
                    numDirectory += 1
                } else {
                    metadatasTemp.insert(metadata, at: numDirectory)
                    numDirectory += 1
                }
            } else {
                if metadata.favorite && directoryOnTop {
                    metadatasFavorite.append(metadata)
                } else {
                    metadatasTemp.append(metadata)
                }
            }
        }
        if directoryOnTop && metadatasFavorite.count > 0 {
            metadatasTemp.insert(contentsOf: metadatasFavorite, at: numDirectory)
        }
        
        self.metadatas = metadatasTemp
    }
        
    // MARK: -

    func getFilesInformation() -> (directories: Int,  files: Int, size: Double) {

        var directories: Int = 0
        var files: Int = 0
        var size: Double = 0

        for metadata in self.metadatas {
            if metadata.directory {
                directories += 1
            } else {
                files += 1
            }
            size = size + metadata.size
        }
        
        return (directories, files, size)
    }
    
    func deleteMetadata(ocId: String) -> Int? {
        
        if let index = self.getIndexMetadata(ocId: ocId) {
            self.metadatas.remove(at: index)
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
            if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
                self.metadatas[index!] = metadata
            } 
        }
        
        return index
    }
    
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
        self.metadatas.append(metadata)
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
        
        return self.metadatas.count
    }
    
    func cellForItemAt(indexPath: IndexPath) -> tableMetadata? {
        
        let row = indexPath.row
        
        if row > self.metadatas.count - 1 {
            return nil
        } else {
            return self.metadatas[row]
        }
    }
}
