// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import LucidBanner

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

            await saveLivePhotoToDisk(metadata: metadata, metadataMov: metadataLive, banner: banner, token: token)
        }
    }

    private func saveLivePhotoToDisk(
        metadata: tableMetadata,
        metadataMov: tableMetadata,
        banner: LucidBanner?,
        token: Int?
    ) async {
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

        NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
            Task { @MainActor in
                banner?.update(
                    payload: LucidBannerPayload.Update(progress: progress),
                    for: token
                )
            }
        }, completion: { _, resources in
            guard let resources else {
                Task { @MainActor in
                    completeHudBannerError(description: "_livephoto_save_error_", token: token, banner: banner)
                }
                return
            }

            NCLivePhoto.saveToLibrary(resources) { result in
                Task { @MainActor in
                    if result {
                        completeHudBannerSuccess(token: token, banner: banner)
                    } else {
                        completeHudBannerError(description: "_livephoto_save_error_", token: token, banner: banner)
                    }
                }
            }
        })
    }
}
