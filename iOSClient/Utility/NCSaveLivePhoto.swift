// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import LucidBanner
import Photos

final class NCSaveLivePhoto: @unchecked Sendable {
    private let metadata: tableMetadata
    private let metadataMOV: tableMetadata
    private let utilityFileSystem = NCUtilityFileSystem()
    private let windowScene: UIWindowScene?

    init(metadata: tableMetadata, metadataMOV: tableMetadata, windowScene: UIWindowScene?) {
        self.metadata = tableMetadata.init(value: metadata)
        self.metadataMOV = tableMetadata.init(value: metadataMOV)
        self.windowScene = windowScene
    }

    func start() {
        Task { [self] in
            let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard authorization == .authorized else {
                await showErrorBanner(windowScene: windowScene, text: "_access_photo_not_enabled_msg_", errorCode: NCGlobal.shared.errorInternalError)
                return
            }

            guard let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(
                ocId: metadata.ocId,
                session: NCNetworking.shared.sessionDownload,
                selector: ""
            ), let metadataLive = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(
                ocId: metadataMOV.ocId,
                session: NCNetworking.shared.sessionDownload,
                selector: ""
            ) else {
                return
            }

            let (banner, token) = await MainActor.run {
                showHudBanner(windowScene: windowScene, title: "_download_image_")
            }

            let resultsMetadata = await NCNetworking.shared.downloadFile(metadata: metadata) { _ in
            } progressHandler: { progress in
                Task { @MainActor in
                    banner?.update(
                        payload: LucidBannerPayload.Update(progress: progress.fractionCompleted),
                        for: token
                    )
                }
            }

            guard resultsMetadata.nkError == .success else {
                await MainActor.run {
                    completeHudBannerError(description: "_livephoto_save_error_", token: token, banner: banner)
                }
                return
            }

            let resultsMetadataLive = await NCNetworking.shared.downloadFile(metadata: metadataLive) { _ in
            } progressHandler: { progress in
                Task { @MainActor in
                    banner?.update(
                        payload: LucidBannerPayload.Update(progress: progress.fractionCompleted),
                        for: token
                    )
                }
            }

            guard resultsMetadataLive.nkError == .success else {
                await MainActor.run {
                    completeHudBannerError(description: "_livephoto_save_error_", token: token, banner: banner)
                }
                return
            }

            await saveLivePhotoToLibrary(metadata: metadata, metadataMov: metadataLive, banner: banner, token: token)
        }
    }

    private func saveLivePhotoToLibrary(metadata: tableMetadata, metadataMov: tableMetadata, banner: LucidBanner?, token: Int?) async {
        let fileNameImage = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(
            metadata.ocId,
            fileName: metadata.fileNameView,
            userId: metadata.userId,
            urlBase: metadata.urlBase
        ))
        let fileNameMov = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(
            metadataMov.ocId,
            fileName: metadataMov.fileNameView,
            userId: metadataMov.userId,
            urlBase: metadataMov.urlBase
        ))

        await MainActor.run {
            banner?.update(
                payload: LucidBannerPayload.Update(title: NSLocalizedString("_livephoto_save_", comment: "")),
                for: token
            )
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                // Photos copies the original resources, keeping the downloaded files in provider storage.
                request.addResource(with: .photo, fileURL: fileNameImage, options: nil)
                request.addResource(with: .pairedVideo, fileURL: fileNameMov, options: nil)
            }
            await MainActor.run {
                completeHudBannerSuccess(token: token, banner: banner)
            }
        } catch {
            await MainActor.run {
                completeHudBannerError(description: "_livephoto_save_error_", token: token, banner: banner)
            }
        }
    }
}
