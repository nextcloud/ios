// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// What the user was doing when an error happened, so the message can say what failed.
enum NCErrorContext: Equatable {
    case generic
    case upload(fileName: String)
    case download(fileName: String)
    case delete(fileName: String)
    case rename
    case moveOrCopy(fileName: String)
    case createFolder(folderName: String)
    case favorite(fileName: String)

    /// The context of a transfer event, from its `networkingStatus`.
    init(networkingStatus: String, fileName: String) {
        let global = NCGlobal.shared

        switch networkingStatus {
        case global.networkingStatusUploading, global.networkingStatusUploaded:
            self = .upload(fileName: fileName)

        case global.networkingStatusDownloading, global.networkingStatusDownloaded:
            self = .download(fileName: fileName)

        case global.networkingStatusDelete:
            self = .delete(fileName: fileName)

        case global.networkingStatusRename:
            self = .rename

        case global.networkingStatusCopyMove:
            self = .moveOrCopy(fileName: fileName)

        case global.networkingStatusCreateFolder:
            self = .createFolder(folderName: fileName)

        case global.networkingStatusFavorite:
            self = .favorite(fileName: fileName)

        default:
            self = .generic
        }
    }

    /// The context of the operation an item is waiting for or failed at, from its metadata `status`.
    init(metadataStatus: Int, fileName: String) {
        let global = NCGlobal.shared

        switch metadataStatus {
        case global.metadataStatusWaitUpload, global.metadataStatusUploading, global.metadataStatusUploadError:
            self = .upload(fileName: fileName)

        case global.metadataStatusWaitDownload, global.metadataStatusDownloading, global.metadataStatusDownloadError:
            self = .download(fileName: fileName)

        case global.metadataStatusWaitDelete:
            self = .delete(fileName: fileName)

        case global.metadataStatusWaitRename:
            self = .rename

        case global.metadataStatusWaitCopy, global.metadataStatusWaitMove:
            self = .moveOrCopy(fileName: fileName)

        case global.metadataStatusWaitCreateFolder:
            self = .createFolder(folderName: fileName)

        case global.metadataStatusWaitFavorite:
            self = .favorite(fileName: fileName)

        default:
            self = .generic
        }
    }

    /// A title saying what failed, e.g. "Couldn't upload “IMG_0042.jpg”"; `nil` for `generic`.
    var failureTitle: String? {
        switch self {
        case .generic:
            return nil

        case .upload(let fileName):
            return String(format: NSLocalizedString("_error_title_upload_", comment: ""), fileName)

        case .download(let fileName):
            return String(format: NSLocalizedString("_error_title_download_", comment: ""), fileName)

        case .delete(let fileName):
            return String(format: NSLocalizedString("_error_title_delete_", comment: ""), fileName)

        case .rename:
            return NSLocalizedString("_error_title_rename_", comment: "")

        case .moveOrCopy(let fileName):
            return String(format: NSLocalizedString("_error_title_move_copy_", comment: ""), fileName)

        case .createFolder(let folderName):
            return String(format: NSLocalizedString("_error_title_create_folder_", comment: ""), folderName)

        case .favorite(let fileName):
            return String(format: NSLocalizedString("_error_title_favorite_", comment: ""), fileName)
        }
    }
}
