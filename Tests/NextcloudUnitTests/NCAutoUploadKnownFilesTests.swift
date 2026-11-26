// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import Nextcloud

@Suite("Auto Upload known files")
struct NCAutoUploadKnownFilesTests {
    @Test("An uploaded asset is found by identifier even when its generated name changed")
    func uploadedAssetMatchesByIdentifier() {
        let knownFiles = NCAutoUploadKnownFiles(
            uploadedFileNames: ["26-11-06 11-41-14 0069.jpg"],
            uploadedFileNamesByAsset: ["asset-1": ["26-11-06 11-41-14 0069.jpg"]]
        )

        #expect(knownFiles.isAssetUploaded("asset-1", isLivePhoto: false))
        #expect(!knownFiles.isFileUploaded(fileName: "26-11-06 11-41-14 0070.jpg",
                                           fileNameCompatible: "26-11-06 11-41-14 0070.jpg",
                                           pairedFileName: "26-11-06 11-41-14 0070.mov",
                                           isLivePhoto: false))
    }

    @Test("A Live Photo counts as uploaded only with both its image and its video")
    func livePhotoNeedsBothParts() {
        let imageOnly = NCAutoUploadKnownFiles(uploadedFileNamesByAsset: ["asset-1": ["photo 0069.jpg"]])
        let videoOnly = NCAutoUploadKnownFiles(uploadedFileNamesByAsset: ["asset-1": ["photo 0069.mov"]])
        let both = NCAutoUploadKnownFiles(uploadedFileNamesByAsset: ["asset-1": ["photo 0069.jpg", "photo 0069.MOV"]])

        #expect(!imageOnly.isAssetUploaded("asset-1", isLivePhoto: true))
        #expect(!videoOnly.isAssetUploaded("asset-1", isLivePhoto: true))
        #expect(both.isAssetUploaded("asset-1", isLivePhoto: true))
    }

    @Test("A photo whose Live part was turned off counts as uploaded with its image alone")
    func livePhotoTurnedOff() {
        let knownFiles = NCAutoUploadKnownFiles(uploadedFileNamesByAsset: ["asset-1": ["photo 0069.jpg"]])

        #expect(knownFiles.isAssetUploaded("asset-1", isLivePhoto: false))
    }

    @Test("An unknown asset is not uploaded, and history without identifiers still matches by name")
    func unknownAssetFallsBackToName() {
        let knownFiles = NCAutoUploadKnownFiles(uploadedFileNames: ["IMG_1234.jpg", "IMG_1234.mov"])

        #expect(!knownFiles.isAssetUploaded("asset-1", isLivePhoto: false))
        #expect(knownFiles.isFileUploaded(fileName: "IMG_1234.heic",
                                          fileNameCompatible: "IMG_1234.jpg",
                                          pairedFileName: "IMG_1234.mov",
                                          isLivePhoto: true))
        #expect(!knownFiles.isFileUploaded(fileName: "IMG_5678.heic",
                                           fileNameCompatible: "IMG_5678.jpg",
                                           pairedFileName: "IMG_5678.mov",
                                           isLivePhoto: false))
    }

    @Test("A queued asset is found by identifier or by name")
    func queuedAsset() {
        let knownFiles = NCAutoUploadKnownFiles(queuedFileNames: ["IMG_1234.mov"], queuedAssets: ["asset-1"])

        #expect(knownFiles.isAssetQueued("asset-1"))
        #expect(!knownFiles.isAssetQueued("asset-2"))
        #expect(knownFiles.isFileQueued(fileName: "IMG_1234.heic",
                                        fileNameCompatible: "IMG_1234.jpg",
                                        pairedFileName: "IMG_1234.mov",
                                        isLivePhoto: true))
        #expect(!knownFiles.isFileQueued(fileName: "IMG_1234.heic",
                                         fileNameCompatible: "IMG_1234.jpg",
                                         pairedFileName: "IMG_1234.mov",
                                         isLivePhoto: false))
    }
}
