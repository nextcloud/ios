// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Testing
@testable import Nextcloud

@Suite("Uploaded camera-roll asset eligibility")
struct NCUploadedAssetsCleanupTests {
    private func metadata(_ identifier: String, fileName: String = "photo.heic") -> tableMetadata {
        let metadata = tableMetadata()
        metadata.ocId = UUID().uuidString
        metadata.assetLocalIdentifier = identifier
        metadata.account = "account"
        metadata.serverUrl = "https://example.com/photos"
        metadata.fileName = fileName
        metadata.status = NCGlobal.shared.metadataStatusNormal
        return metadata
    }

    private func livePhoto() -> [tableMetadata] {
        let image = metadata("live", fileName: "photo.heic")
        image.classFile = NKTypeClassFile.image.rawValue
        image.livePhotoFile = "photo.mov"
        let video = metadata("live", fileName: "photo.mov")
        video.classFile = NKTypeClassFile.video.rawValue
        video.livePhotoFile = "photo.heic"
        return [image, video]
    }

    @Test("Unrelated pending transfers do not block completed photos")
    func unrelatedTransfers() {
        let completed = metadata("completed")
        let pending = metadata("pending")
        pending.status = NCGlobal.shared.metadataStatusWaitUpload
        let failed = metadata("failed")
        failed.status = NCGlobal.shared.metadataStatusUploadError
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: [completed, pending, failed]) == ["completed"])
    }

    @Test("Every transfer of the same asset must be complete, including other accounts")
    func sameAssetPending() {
        let completed = metadata("asset")
        let pending = metadata("asset")
        pending.account = "another-account"
        pending.status = NCGlobal.shared.metadataStatusUploading
        pending.backgroundUploadJobIdentifier = "photokit-job"
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: [completed, pending]).isEmpty)
    }

    @Test("Completed identifiers are unique and empty identifiers are ignored")
    func uniqueIdentifiers() {
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: [metadata("asset"), metadata("asset"), metadata("")]) == ["asset"])
    }

    @Test("Live Photos require both completed components")
    func incompleteLivePhoto() {
        let pair = livePhoto()
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: [pair[0]]).isEmpty)
        pair[1].status = NCGlobal.shared.metadataStatusUploadError
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: pair).isEmpty)
        pair[1].status = NCGlobal.shared.metadataStatusNormal
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: pair) == ["live"])
    }

    @Test("Live Photo companions must match their account, folder and link")
    func companionScope() {
        let pair = livePhoto()
        pair[1].account = "another-account"
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: pair).isEmpty)
        pair[1].account = pair[0].account
        pair[1].serverUrl = "https://example.com/other"
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: pair).isEmpty)
        pair[1].serverUrl = pair[0].serverUrl
        pair[0].livePhotoFile = "missing.mov"
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: pair).isEmpty)
    }

    @Test("Server file IDs are accepted after Live Photo pairing")
    func pairedFileIdentifiers() {
        let pair = livePhoto()
        pair[0].fileId = "image-id"
        pair[1].fileId = "video-id"
        pair[0].livePhotoFile = "video-id"
        pair[1].livePhotoFile = "image-id"
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: pair) == ["live"])
    }

    @Test("Cancellation-requested assets are retained")
    func cancelledAsset() {
        let asset = metadata("asset")
        asset.backgroundUploadCancellationRequested = true
        #expect(NCManageDatabase.uploadedAssetLocalIdentifiers(in: [asset]).isEmpty)
    }
}
