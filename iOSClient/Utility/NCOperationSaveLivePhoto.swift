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
    var scene: UIWindowScene?
    var tokenBanner: Int?

    init(metadata: tableMetadata, metadataMOV: tableMetadata, controller: UITabBarController?) {
        self.metadata = tableMetadata.init(value: metadata)
        self.metadataMOV = tableMetadata.init(value: metadataMOV)
        scene = SceneManager.shared.getWindow(controller: controller)?.windowScene
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
            tokenBanner = showHudBanner(scene: scene, title: NSLocalizedString("_download_image_", comment: ""))

            let resultsMetadata = await NCNetworking.shared.downloadFile(metadata: metadata) { _ in
            } progressHandler: { progress in
                Task {@MainActor in
                    LucidBanner.shared.update(
                        payload: LucidBannerPayload.Update(progress: progress.fractionCompleted),
                        for: self.tokenBanner)
                }
            }

            guard resultsMetadata.nkError == .success else {
                Task {@MainActor in
                    completeHudBannerError(subtitle: NSLocalizedString("_livephoto_save_error_", comment: ""), token: self.tokenBanner)
                }
                return self.finish()
            }

            let resultsMetadataLive = await NCNetworking.shared.downloadFile(metadata: metadataLive) { _ in
            } progressHandler: { progress in
                Task {@MainActor in
                    LucidBanner.shared.update(
                        payload: LucidBannerPayload.Update(progress: progress.fractionCompleted),
                        for: self.tokenBanner)
                }
            }

            guard resultsMetadataLive.nkError == .success else {
                Task {@MainActor in
                    completeHudBannerError(subtitle: NSLocalizedString("_livephoto_save_error_", comment: ""), token: self.tokenBanner)
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
        LucidBanner.shared.update(payload: payload, for: self.tokenBanner)

        NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
            Task {@MainActor in
                LucidBanner.shared.update(
                    payload: LucidBannerPayload.Update(progress: progress),
                    for: self.tokenBanner)
            }
        }, completion: { _, resources in
            if let resources {
                NCLivePhoto.saveToLibrary(resources) { result in
                    Task {@MainActor in
                        if !result {
                            completeHudBannerError(subtitle: NSLocalizedString("_livephoto_save_error_", comment: ""), token: self.tokenBanner)
                        } else {
                            completeHudBannerSuccess(token: self.tokenBanner)
                        }
                        return self.finish()
                    }
                }
            } else {
                Task {@MainActor in
                    completeHudBannerError(subtitle: NSLocalizedString("_livephoto_save_error_", comment: ""), token: self.tokenBanner)
                    return self.finish()
                }
            }
        })
    }
}
