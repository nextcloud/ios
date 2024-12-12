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
import UniformTypeIdentifiers

class FileProviderItem: NSObject, NSFileProviderItem {
    var metadata: tableMetadata
    /// Providing Required Properties
    var itemIdentifier: NSFileProviderItemIdentifier {
        return fileProviderUtility().getItemIdentifier(metadata: metadata)
    }
    var filename: String {
        return metadata.fileNameView
    }
    var typeIdentifier: String {
        let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: metadata.fileNameView, mimeType: "", directory: metadata.directory, account: metadata.account)
        return results.typeIdentifier
    }
    var capabilities: NSFileProviderItemCapabilities {
        if metadata.directory {
            return [ .allowsAddingSubItems, .allowsContentEnumerating, .allowsReading, .allowsDeleting, .allowsRenaming ]
        } else if metadata.lock {
            return [ .allowsReading ]
        }
        return [ .allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting ]
    }
    /// Managing Content
    var childItemCount: NSNumber? {
        return metadata.directory ? nil : nil
    }
    var documentSize: NSNumber? {
        return metadata.directory ? nil : NSNumber(value: metadata.size)
    }
    /// Specifying Content Location
    var parentItemIdentifier: NSFileProviderItemIdentifier
    var isTrashed: Bool {
        return false
    }
    var symlinkTargetPath: String? {
        return nil
    }
    /// Tracking Usage
    var contentModificationDate: Date? {
        return metadata.date as Date
    }
    var creationDate: Date? {
        return metadata.creationDate as Date
    }
    var lastUsedDate: Date? {
        return metadata.date as Date
    }
    /// Tracking Versions
    var versionIdentifier: Data? {
        return metadata.etag.data(using: .utf8)
    }
    var isMostRecentVersionDownloaded: Bool {
        if NCManageDatabase.shared.getTableLocalFile(ocId: metadata.ocId) == nil {
            return false
        } else {
            return true
        }
    }
    /// Monitoring File Transfers
    var isUploading: Bool {
        if metadata.status == NCGlobal.shared.metadataStatusWaitUpload || metadata.status == NCGlobal.shared.metadataStatusUploading {
            return true
        } else {
            return false
        }
    }
    var isUploaded: Bool {
        if metadata.status == NCGlobal.shared.metadataStatusWaitUpload || metadata.status == NCGlobal.shared.metadataStatusUploading || metadata.status == NCGlobal.shared.metadataStatusUploadError {
            return false
        } else {
            return true
        }
    }
    var uploadingError: Error? {
        if metadata.status == NCGlobal.shared.metadataStatusUploadError {
            return fileProviderData.FileProviderError.uploadError
        } else {
            return nil
        }
    }
    var isDownloading: Bool {
        if metadata.status == NCGlobal.shared.metadataStatusWaitDownload || metadata.status == NCGlobal.shared.metadataStatusDownloading {
            return true
        } else {
            return false
        }
    }
    var isDownloaded: Bool {
        if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
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
    /// Sharing
    /// Managing Metadata
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

    init(metadata: tableMetadata, parentItemIdentifier: NSFileProviderItemIdentifier) {
        self.metadata = tableMetadata(value: metadata)
        self.parentItemIdentifier = parentItemIdentifier
    }
}
