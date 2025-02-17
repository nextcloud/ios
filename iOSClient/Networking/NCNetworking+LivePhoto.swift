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
    func createLivePhoto(metadata: tableMetadata, userInfo aUserInfo: [AnyHashable: Any]) {
        database.realmRefresh()
        guard let metadataLast = database.getMetadata(predicate: NSPredicate(format: "account == %@ AND urlBase == %@ AND path == %@ AND fileName == %@",
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
        if metadataLast.status != self.global.metadataStatusNormal {
            return NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Upload set LivePhoto for files (NO Status Normal) " + (metadataLast.fileName as NSString).deletingPathExtension)
        }

        Task {
            await setLivePhoto(metadataFirst: metadata, metadataLast: metadataLast, userInfo: aUserInfo)
        }
    }

    func setLivePhoto(metadataFirst: tableMetadata?, metadataLast: tableMetadata?, userInfo aUserInfo: [AnyHashable: Any], livePhoto: Bool = true) async {
        guard let metadataFirst, let metadataLast = metadataLast else { return }
        var livePhotoFileId = ""

        /// METADATA FIRST
        let serverUrlfileNamePathFirst = metadataFirst.urlBase + metadataFirst.path + metadataFirst.fileName
        if livePhoto {
            livePhotoFileId = metadataLast.fileId
        }
        let resultsMetadataFirst = await setLivephoto(serverUrlfileNamePath: serverUrlfileNamePathFirst, livePhotoFile: livePhotoFileId, account: metadataFirst.account)
        if resultsMetadataFirst.error == .success {
            database.setMetadataLivePhotoByServer(account: metadataFirst.account, ocId: metadataFirst.ocId, livePhotoFile: livePhotoFileId)
        }

        ///  METADATA LAST
        let serverUrlfileNamePathLast = metadataLast.urlBase + metadataLast.path + metadataLast.fileName
        if livePhoto {
            livePhotoFileId = metadataFirst.fileId
        }
        let resultsMetadataLast = await setLivephoto(serverUrlfileNamePath: serverUrlfileNamePathLast, livePhotoFile: livePhotoFileId, account: metadataLast.account)
        if resultsMetadataLast.error == .success {
            database.setMetadataLivePhotoByServer(account: metadataLast.account, ocId: metadataLast.ocId, livePhotoFile: livePhotoFileId)
        }

        if resultsMetadataFirst.error == .success, resultsMetadataLast.error == .success {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload set LivePhoto for files " + (metadataFirst.fileName as NSString).deletingPathExtension)
        } else {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Upload set LivePhoto with error \(resultsMetadataFirst.error.errorCode) - \(resultsMetadataLast.error.errorCode)")
        }

        NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterUploadedLivePhoto,
                                                    object: nil,
                                                    userInfo: aUserInfo,
                                                    second: 0.5)
    }
}
