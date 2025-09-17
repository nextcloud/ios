//
//  NCNetworking+LivePhoto.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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
import NextcloudKit
import Queuer

extension NCNetworking {
    func setLivePhoto(account: String) async {
        if let results = await NCManageDatabase.shared.getLivePhotos(account: account) {
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
                    await NCManageDatabase.shared.setLivePhotoError(account: account, serverUrlFileNameNoExt: result.serverUrlFileNameNoExt)
                    return
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
                    await NCManageDatabase.shared.setLivePhotoError(account: account, serverUrlFileNameNoExt: result.serverUrlFileNameNoExt)
                    return
                }

                await NCManageDatabase.shared.setLivePhotoFile(ocId: result.fileIdVideo, livePhotoFile: result.fileIdImage)
                await NCManageDatabase.shared.setLivePhotoFile(ocId: result.fileIdImage, livePhotoFile: result.fileIdVideo)

                await NCManageDatabase.shared.deleteLivePhoto(account: account, serverUrlFileNameNoExt: result.serverUrlFileNameNoExt)
            }
        }
    }
}
