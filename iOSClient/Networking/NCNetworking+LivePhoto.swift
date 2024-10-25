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
import Alamofire
import Queuer

extension NCNetworking {
    func uploadLivePhoto(metadata: tableMetadata, userInfo aUserInfo: [AnyHashable: Any]) {
        database.realmRefresh()
        guard let metadata1 = database.getMetadata(predicate: NSPredicate(format: "account == %@ AND urlBase == %@ AND path == %@ AND fileName == %@",
                                                                          metadata.account,
                                                                          metadata.urlBase,
                                                                          metadata.path,
                                                                          metadata.livePhotoFile)) else {
            metadata.livePhotoFile = ""
            self.database.addMetadata(metadata)
            return NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterUploadedLivePhoto,
                                                               object: nil,
                                                               userInfo: aUserInfo,
                                                               second: 0.5)
        }
        if metadata1.status != self.global.metadataStatusNormal {
            return NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Upload set LivePhoto for files (NO Status Normal) " + (metadata1.fileName as NSString).deletingPathExtension)
        }

        Task {

            /// METADATA
            let serverUrlfileNamePath = metadata.urlBase + metadata.path + metadata.fileName
            var livePhotoFile = metadata1.fileId
            let resultsMetadata = await setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath, livePhotoFile: livePhotoFile, account: metadata.account)
            if resultsMetadata.error == .success {
                database.setMetadataLivePhotoByServer(account: metadata.account, ocId: metadata.ocId, livePhotoFile: livePhotoFile)
            }

            /// METADATA 1
            let serverUrlfileNamePath1 = metadata1.urlBase + metadata1.path + metadata1.fileName
            livePhotoFile = metadata.fileId
            let resultsMetadata1 = await setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath1, livePhotoFile: livePhotoFile, account: metadata1.account)
            if resultsMetadata1.error == .success {
                database.setMetadataLivePhotoByServer(account: metadata1.account, ocId: metadata1.ocId, livePhotoFile: livePhotoFile)
            }

            if resultsMetadata.error == .success, resultsMetadata1.error == .success {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload set LivePhoto for files " + (metadata.fileName as NSString).deletingPathExtension)
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Upload set LivePhoto with error \(resultsMetadata.error.errorCode) - \(resultsMetadata1.error.errorCode)")
            }

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterUploadedLivePhoto,
                                                        object: nil,
                                                        userInfo: aUserInfo,
                                                        second: 0.5)
        }
    }
}
