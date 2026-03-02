// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import Queuer
import NextcloudKit
import LucidBanner

class NCOperationSaveLivePhoto: ConcurrentOperation, @unchecked Sendable {
    var metadata: tableMetadata
    var metadataMOV: tableMetadata
    let utilityFileSystem = NCUtilityFileSystem()
    var windowScene: UIWindowScene?
    var token: Int?
    var banner: LucidBanner?

    init(metadata: tableMetadata, metadataMOV: tableMetadata, windowScene: UIWindowScene?) {
        self.metadata = tableMetadata.init(value: metadata)
        self.metadataMOV = tableMetadata.init(value: metadataMOV)
        self.windowScene = windowScene
    }

    override func start() {
        Task {@MainActor in
            guard !isCancelled,
                  let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                                     session: NCNetworking.shared.sessionDownload,
                                                                                                     selector: ""),
                  let metadataLive = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(ocId: metadataMOV.ocId,
                                                                                                         session: NCNetworking.shared.sessionDownload,
                                                                                                         selector: "") else {
                return self.finish()
            }
            (banner, token) = showHudBanner(windowScene: windowScene, title: "_download_image_")

            let resultsMetadata = await NCNetworking.shared.downloadFile(metadata: metadata) { _ in
            } progressHandler: { progress in
                Task {@MainActor in
                    self.banner?.update(
                        payload: LucidBannerPayload.Update(progress: progress.fractionCompleted),
                        for: self.token)
                }
            }

            guard resultsMetadata.nkError == .success else {
                Task {@MainActor in
                    completeHudBannerError(description: "_livephoto_save_error_", token: self.token, banner: self.banner)
                }
                return self.finish()
            }

            let resultsMetadataLive = await NCNetworking.shared.downloadFile(metadata: metadataLive) { _ in
            } progressHandler: { progress in
                Task {@MainActor in
                    self.banner?.update(
                        payload: LucidBannerPayload.Update(progress: progress.fractionCompleted),
                        for: self.token)
                }
            }

            guard resultsMetadataLive.nkError == .success else {
                Task {@MainActor in
                    completeHudBannerError(description: "_livephoto_save_error_", token: self.token, banner: self.banner)
                }
                return self.finish()
            }

            // LucidBanner.shared.dismiss()
            self.saveLivePhotoToDisk(metadata: self.metadata, metadataMov: self.metadataMOV)
        }
    }

    @MainActor
    func saveLivePhotoToDisk(metadata: tableMetadata, metadataMov: tableMetadata) {
        let fileNameImage = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                                   fileName: metadata.fileNameView,
                                                                                                   userId: metadata.userId,
                                                                                                   urlBase: metadata.urlBase))
        let fileNameMov = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataMov.ocId,
                                                                                                 fileName: metadataMov.fileNameView,
                                                                                                 userId: metadataMov.userId,
                                                                                                 urlBase: metadataMov.urlBase))

        let payload = LucidBannerPayload.Update(
            title: NSLocalizedString("_livephoto_save_", comment: ""),
        )
        banner?.update(payload: payload, for: self.token)

        NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
            Task {@MainActor in
                self.banner?.update(
                    payload: LucidBannerPayload.Update(progress: progress),
                    for: self.token)
            }
        }, completion: { _, resources in
            if let resources {
                NCLivePhoto.saveToLibrary(resources) { result in
                    Task {@MainActor in
                        if !result {
                            completeHudBannerError(description: "_livephoto_save_error_", token: self.token, banner: self.banner)
                        } else {
                            completeHudBannerSuccess(token: self.token, banner: self.banner)
                        }
                        return self.finish()
                    }
                }
            } else {
                Task {@MainActor in
                    completeHudBannerError(description: "_livephoto_save_error_", token: self.token, banner: self.banner)
                    return self.finish()
                }
            }
        })
    }
}
