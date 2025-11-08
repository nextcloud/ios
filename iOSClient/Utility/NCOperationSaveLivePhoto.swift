// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later


import UIKit
import Queuer
import NextcloudKit

class NCOperationSaveLivePhoto: ConcurrentOperation, @unchecked Sendable {
    var metadata: tableMetadata
    var metadataMOV: tableMetadata
    let hud: NCHud?
    let utilityFileSystem = NCUtilityFileSystem()

    init(metadata: tableMetadata, metadataMOV: tableMetadata, hudView: UIView) {
        self.metadata = tableMetadata.init(value: metadata)
        self.metadataMOV = tableMetadata.init(value: metadataMOV)
        self.hud = NCHud(hudView)
        hud?.ringProgress(text: NSLocalizedString("_download_image_", comment: ""), detailText: self.metadata.fileName)
    }

    override func start() {
        Task {
            guard !isCancelled,
                  let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                                     session: NCNetworking.shared.sessionDownload,
                                                                                                     selector: ""),
                  let metadataLive = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(ocId: metadataMOV.ocId,
                                                                                                         session: NCNetworking.shared.sessionDownload,
                                                                                                         selector: "") else {
                return self.finish()
            }

            let resultsMetadata = await NCNetworking.shared.downloadFile(metadata: metadata) { _ in
            } progressHandler: { progess in
                self.hud?.progress(progess.fractionCompleted)
            }
            guard resultsMetadata.nkError == .success else {
                self.hud?.error(text: NSLocalizedString("_livephoto_save_error_", comment: ""))
                return self.finish()
            }

            let resultsMetadataLive = await NCNetworking.shared.downloadFile(metadata: metadataLive) { _ in
            } progressHandler: { progess in
                self.hud?.progress(progess.fractionCompleted)
            }
            guard resultsMetadataLive.nkError == .success else {
                self.hud?.error(text: NSLocalizedString("_livephoto_save_error_", comment: ""))
                return self.finish()
            }
            self.saveLivePhotoToDisk(metadata: self.metadata, metadataMov: self.metadataMOV)
        }
    }

    func saveLivePhotoToDisk(metadata: tableMetadata, metadataMov: tableMetadata) {
        let fileNameImage = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                                   fileName: metadata.fileNameView,
                                                                                                   userId: metadata.userId,
                                                                                                   urlBase: metadata.urlBase))
        let fileNameMov = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataMov.ocId,
                                                                                                 fileName: metadataMov.fileNameView,
                                                                                                 userId: metadataMov.userId,
                                                                                                 urlBase: metadataMov.urlBase))

        self.hud?.progress(0)
        self.hud?.setText(NSLocalizedString("_livephoto_save_", comment: ""))

        NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
            self.hud?.progress(progress)
        }, completion: { _, resources in
            if let resources {
                NCLivePhoto.saveToLibrary(resources) { result in
                    if !result {
                        self.hud?.error(text: NSLocalizedString("_livephoto_save_error_", comment: ""))
                    } else {
                        self.hud?.success()
                    }
                    return self.finish()
                }
            } else {
                self.hud?.error(text: NSLocalizedString("_livephoto_save_error_", comment: ""))
                return self.finish()
            }
        })
    }
}
