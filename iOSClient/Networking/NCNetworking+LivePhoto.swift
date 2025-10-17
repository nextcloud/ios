// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Queuer

extension NCNetworking {
    @discardableResult
    func setLivePhoto(account: String) async -> Bool {
        var setLivePhoto: Bool = false
        let results = await NCManageDatabase.shared.getLivePhotos(account: account, notSkip: true)
        guard let results,
              !results.isEmpty else {
            return setLivePhoto
        }

        for result in results {

            // VIDEO PART
            //
            let resultLivePhotoVideo = await NextcloudKit.shared.setLivephotoAsync(serverUrlfileNamePath: result.serverUrlFileNameVideo, livePhotoFile: result.fileIdImage, account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                path: result.serverUrlFileNameVideo,
                                                                                                name: "setLivephoto")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            guard resultLivePhotoVideo.error == .success else {
                nkLog(error: "Upload set LivePhoto Video with error \(resultLivePhotoVideo.error.errorCode)")
                await NCManageDatabase.shared.setLivePhotoError(account: account, serverUrlFileNameNoExt: result.serverUrlFileNameNoExt, notSkip: true)
                return false
            }

            // IMAGE PART
            //
            let resultLivePhotoImage = await NextcloudKit.shared.setLivephotoAsync(serverUrlfileNamePath: result.serverUrlFileNameImage, livePhotoFile: result.fileIdVideo, account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                path: result.serverUrlFileNameImage,
                                                                                                name: "setLivephoto")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            guard resultLivePhotoImage.error == .success else {
                nkLog(error: "Upload set LivePhoto Image with error \(resultLivePhotoImage.error.errorCode)")
                await NCManageDatabase.shared.setLivePhotoError(account: account, serverUrlFileNameNoExt: result.serverUrlFileNameNoExt, notSkip: true)
                return false
            }

            await NCManageDatabase.shared.setLivePhotoFile(fileId: result.fileIdVideo, livePhotoFile: result.fileIdImage, notSkip: true)
            await NCManageDatabase.shared.setLivePhotoFile(fileId: result.fileIdImage, livePhotoFile: result.fileIdVideo, notSkip: true)
            await NCManageDatabase.shared.deleteLivePhoto(account: account, serverUrlFileNameNoExt: result.serverUrlFileNameNoExt, notSkip: true)

            setLivePhoto = true
        }

        return setLivePhoto
    }
}
