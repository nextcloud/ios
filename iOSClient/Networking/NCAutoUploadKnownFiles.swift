// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// What Auto Upload already knows about a destination: files waiting in the queue and
/// files recorded as uploaded, both by generated file name and by Photos asset.
///
/// A generated file name is not stable when the original name has no digits, because
/// the name then takes a counter that changes on every call. Matching by asset first
/// keeps those photos from being uploaded again under a new name on every pass.
struct NCAutoUploadKnownFiles: Sendable {
    let queuedFileNames: Set<String>
    let uploadedFileNames: Set<String>
    let queuedAssets: Set<String>
    let uploadedFileNamesByAsset: [String: Set<String>]

    init(queuedFileNames: Set<String> = [],
         uploadedFileNames: Set<String> = [],
         queuedAssets: Set<String> = [],
         uploadedFileNamesByAsset: [String: Set<String>] = [:]) {
        self.queuedFileNames = queuedFileNames
        self.uploadedFileNames = uploadedFileNames
        self.queuedAssets = queuedAssets
        self.uploadedFileNamesByAsset = uploadedFileNamesByAsset
    }

    /// Whether the history records this asset as uploaded. A Live Photo counts only
    /// when both its image and its paired `.mov` were uploaded.
    func isAssetUploaded(_ assetLocalIdentifier: String, isLivePhoto: Bool) -> Bool {
        guard let fileNames = uploadedFileNamesByAsset[assetLocalIdentifier], !fileNames.isEmpty else {
            return false
        }
        guard isLivePhoto else {
            return true
        }
        let isMovie: (String) -> Bool = { ($0 as NSString).pathExtension.lowercased() == "mov" }
        return fileNames.contains(where: isMovie) && fileNames.contains { !isMovie($0) }
    }

    /// Whether the history records a file with this generated name as uploaded.
    func isFileUploaded(fileName: String, fileNameCompatible: String, pairedFileName: String, isLivePhoto: Bool) -> Bool {
        let primaryUploaded = uploadedFileNames.contains(fileNameCompatible) || uploadedFileNames.contains(fileName)
        return primaryUploaded && (!isLivePhoto || uploadedFileNames.contains(pairedFileName))
    }

    func isAssetQueued(_ assetLocalIdentifier: String) -> Bool {
        queuedAssets.contains(assetLocalIdentifier)
    }

    func isFileQueued(fileName: String, fileNameCompatible: String, pairedFileName: String, isLivePhoto: Bool) -> Bool {
        queuedFileNames.contains(fileNameCompatible) || queuedFileNames.contains(fileName) ||
            (isLivePhoto && queuedFileNames.contains(pairedFileName))
    }
}
