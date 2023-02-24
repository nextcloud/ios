//
//  FileProviderItem.swift
//  Files
//
//  Created by Marino Faggiana on 26/03/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
import FileProvider
import NextcloudKit

class FileProviderItem: NSObject, NSFileProviderItem {

    var metadata: tableMetadata
    var parentItemIdentifier: NSFileProviderItemIdentifier

    var itemIdentifier: NSFileProviderItemIdentifier {
        return fileProviderUtility.shared.getItemIdentifier(metadata: metadata)
    }

    var filename: String {
        return metadata.fileNameView
    }

    var documentSize: NSNumber? {
        return NSNumber(value: metadata.size)
    }

    var typeIdentifier: String {
        let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: metadata.fileNameView, mimeType: "", directory: metadata.directory)
        return results.typeIdentifier
    }

    var contentModificationDate: Date? {
        return metadata.date as Date
    }

    var creationDate: Date? {
        return metadata.creationDate as Date
    }

    var lastUsedDate: Date? {
        return metadata.date as Date
    }

    var capabilities: NSFileProviderItemCapabilities {
        guard !metadata.directory else {
            return [ .allowsAddingSubItems, .allowsContentEnumerating, .allowsReading, .allowsDeleting, .allowsRenaming ]
        }
        guard !metadata.lock else {
            return [ .allowsReading ]
        }
        return [ .allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting ]
    }

    var isTrashed: Bool {
        return false
    }

    var childItemCount: NSNumber? {
        return nil
    }

    var versionIdentifier: Data? {
        return metadata.etag.data(using: .utf8)
    }

    var tagData: Data? {
        if let tableTag = NCManageDatabase.shared.getTag(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            return tableTag.tagIOS
        } else {
            return nil
        }
    }

    var favoriteRank: NSNumber? {
        if let rank = fileProviderData.shared.listFavoriteIdentifierRank[metadata.ocId] {
            return rank
        } else {
            return nil
        }
    }

    var isMostRecentVersionDownloaded: Bool {
        return true
    }

    var isDownloaded: Bool {
        if metadata.directory {
            return true
        }
        if CCUtility.fileProviderStorageExists(metadata) {
            return true
        } else {
            return false
        }
    }

    var isDownloading: Bool {
        if metadata.status == NCGlobal.shared.metadataStatusDownloading {
            return true
        } else {
            return false
        }
    }

    var downloadingError: Error? {
        if metadata.status == NCGlobal.shared.metadataStatusDownloadError {
            return fileProviderData.FileProviderError.downloadError
        } else {
            return nil
        }
    }

    var isUploaded: Bool {
        if NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) != nil {
            return true
        } else {
            return false
        }
    }

    var isUploading: Bool {
        if metadata.status == NCGlobal.shared.metadataStatusUploading {
            return true
        } else {
            return false
        }
    }

    var uploadingError: Error? {
        if metadata.status == NCGlobal.shared.metadataStatusUploadError {
            return fileProviderData.FileProviderError.uploadError
        } else {
            return nil
        }
    }

    init(metadata: tableMetadata, parentItemIdentifier: NSFileProviderItemIdentifier) {
        self.metadata = metadata
        self.parentItemIdentifier = parentItemIdentifier
    }
}
