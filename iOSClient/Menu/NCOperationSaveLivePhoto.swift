//
//  NCOperationSaveLivePhoto.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/10/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

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
        self.hud?.setText(text: NSLocalizedString("_livephoto_save_", comment: ""))

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
