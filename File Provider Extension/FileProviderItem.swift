// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import FileProvider
import NextcloudKit
import UniformTypeIdentifiers

class FileProviderItem: NSObject, NSFileProviderItem {
    var metadata: tableMetadata

    /// Providing Required Properties
    var itemIdentifier: NSFileProviderItemIdentifier {
        return NSFileProviderItemIdentifier(metadata.ocId)
    }
    var filename: String {
        return metadata.fileNameView
    }
    var typeIdentifier: String {
        return metadata.typeIdentifier
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
        if metadata.directory {
            return true
        }
        let path = NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let fileSize = attributes[.size] as? UInt64 else {
                return false
            }
        return fileSize > 0
    }
    /// Monitoring File Transfers
    var isUploading: Bool {
        return metadata.status == NCGlobal.shared.metadataStatusUploading || metadata.status == NCGlobal.shared.metadataStatusWaitUpload
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
            return FileProviderData.FileProviderError.uploadError
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
        if metadata.directory {
            return true
        }
        let path = NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let fileSize = attributes[.size] as? UInt64 else {
                return false
            }
        return fileSize > 0
    }
    var downloadingError: Error? {
        if metadata.status == NCGlobal.shared.metadataStatusDownloadError {
            return FileProviderData.FileProviderError.downloadError
        } else {
            return nil
        }
    }
    /// Sharing
    /// Managing Metadata
    var tagData: Data? {
        return nil
    }
    var favoriteRank: NSNumber? {
        if let rank = FileProviderData.shared.listFavoriteIdentifierRank[metadata.ocId] {
            return rank
        } else {
            return nil
        }
    }

    init(metadata: tableMetadata, parentItemIdentifier: NSFileProviderItemIdentifier) {
        self.metadata = metadata.detachedCopy()
        if metadata.ocId == "root" {
            self.parentItemIdentifier = .rootContainer
        } else {
            self.parentItemIdentifier = parentItemIdentifier
        }
    }
}
