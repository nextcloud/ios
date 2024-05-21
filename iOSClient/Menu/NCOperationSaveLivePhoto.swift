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
import JGProgressHUD
import NextcloudKit

class NCOperationSaveLivePhoto: ConcurrentOperation {

    var metadata: tableMetadata
    var metadataMOV: tableMetadata
    let hud = JGProgressHUD()
    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    let utilityFileSystem = NCUtilityFileSystem()
    let hudView: UIView

    init(metadata: tableMetadata, metadataMOV: tableMetadata, hudView: UIView) {
        self.metadata = tableMetadata.init(value: metadata)
        self.metadataMOV = tableMetadata.init(value: metadataMOV)
        self.hudView = hudView
    }

    override func start() {
        guard !isCancelled,
            let metadata = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                     session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                     selector: ""),
            let metadataLive = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadataMOV],
                                                                                         session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                         selector: "") else { return self.finish() }
        DispatchQueue.main.async {
            self.hud.indicatorView = JGProgressHUDRingIndicatorView()
            if let indicatorView = self.hud.indicatorView as? JGProgressHUDRingIndicatorView {
                indicatorView.ringWidth = 1.5
                indicatorView.ringColor = NCBrandColor.shared.brandElement
            }
            self.hud.textLabel.text = NSLocalizedString("_download_image_", comment: "")
            self.hud.detailTextLabel.text = self.metadata.fileName
            self.hud.detailTextLabel.textColor = NCBrandColor.shared.iconImageColor2
            self.hud.show(in: self.hudView)
        }

        NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: false) {
        } requestHandler: { _ in
        } progressHandler: { progress in
            self.hud.progress = Float(progress.fractionCompleted)
        } completion: { _, error in
            guard error == .success else {
                DispatchQueue.main.async {
                    self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    self.hud.textLabel.text = NSLocalizedString("_livephoto_save_error_", comment: "")
                    self.hud.dismiss()
                }
                return self.finish()
            }
            NCNetworking.shared.download(metadata: metadataLive, withNotificationProgressTask: false) {
                DispatchQueue.main.async {
                    self.hud.textLabel.text = NSLocalizedString("_download_video_", comment: "")
                    self.hud.detailTextLabel.text = self.metadataMOV.fileName
                }
            } progressHandler: { progress in
                self.hud.progress = Float(progress.fractionCompleted)
            } completion: { _, error in
                guard error == .success else {
                    DispatchQueue.main.async {
                        self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                        self.hud.textLabel.text = NSLocalizedString("_livephoto_save_error_", comment: "")
                        self.hud.dismiss()
                    }
                    return self.finish()
                }
                self.saveLivePhotoToDisk(metadata: self.metadata, metadataMov: self.metadataMOV)
            }
        }
    }

    func saveLivePhotoToDisk(metadata: tableMetadata, metadataMov: tableMetadata) {

        let fileNameImage = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
        let fileNameMov = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataMov.ocId, fileNameView: metadataMov.fileNameView))

        DispatchQueue.main.async {
            self.hud.textLabel.text = NSLocalizedString("_livephoto_save_", comment: "")
            self.hud.detailTextLabel.text = ""
        }

        NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
            self.hud.progress = Float(progress)
        }, completion: { _, resources in
            if let resources {
                NCLivePhoto.saveToLibrary(resources) { result in
                    DispatchQueue.main.async {
                        if !result {
                            self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                            self.hud.textLabel.text = NSLocalizedString("_livephoto_save_error_", comment: "")
                        } else {
                            self.hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                            self.hud.indicatorView?.tintColor = NCBrandColor.shared.brandElement
                            self.hud.textLabel.text = NSLocalizedString("_success_", comment: "")
                        }
                        self.hud.dismiss()
                    }
                    return self.finish()
                }
            } else {
                DispatchQueue.main.async {
                    self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    self.hud.textLabel.text = NSLocalizedString("_livephoto_save_error_", comment: "")
                    self.hud.dismiss()
                }
                return self.finish()
            }
        })
    }
}
