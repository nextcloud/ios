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
    func createLivePhoto(metadata: tableMetadata, userInfo aUserInfo: [AnyHashable: Any]? = nil) {
        database.getMetadataAsync(predicate: NSPredicate(format: "account == %@ AND urlBase == %@ AND path == %@ AND fileNameView == %@",
                                                         metadata.account,
                                                         metadata.urlBase,
                                                         metadata.path,
                                                         metadata.livePhotoFile)) { metadataLast in
            if let metadataLast {
                if metadataLast.status != self.global.metadataStatusNormal {
                    return NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Upload set LivePhoto for files (NO Status Normal) " + (metadataLast.fileName as NSString).deletingPathExtension)
                }
                Task {
                    await self.setLivePhoto(metadataFirst: metadata, metadataLast: metadataLast, userInfo: aUserInfo)
                }
            } else {
                metadata.livePhotoFile = ""
                self.database.addMetadata(metadata, sync: false)
                self.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusUploadedLivePhoto,
                                            metadata: tableMetadata(value: metadata),
                                            error: .success)
                }
            }
        }
    }

    func setLivePhoto(metadataFirst: tableMetadata?, metadataLast: tableMetadata?, userInfo aUserInfo: [AnyHashable: Any]? = nil, livePhoto: Bool = true) async {
        guard let metadataFirst, let metadataLast = metadataLast else { return }
        var livePhotoFileId = ""

        /// METADATA FIRST
        let serverUrlfileNamePathFirst = metadataFirst.urlBase + metadataFirst.path + metadataFirst.fileName
        if livePhoto {
            livePhotoFileId = metadataLast.fileId
        }
        let resultsMetadataFirst = await NextcloudKit.shared.setLivephoto(serverUrlfileNamePath: serverUrlfileNamePathFirst, livePhotoFile: livePhotoFileId, account: metadataFirst.account)
        if resultsMetadataFirst.error == .success {
            database.setMetadataLivePhotoByServer(account: metadataFirst.account, ocId: metadataFirst.ocId, livePhotoFile: livePhotoFileId, sync: false)
        }

        ///  METADATA LAST
        let serverUrlfileNamePathLast = metadataLast.urlBase + metadataLast.path + metadataLast.fileName
        if livePhoto {
            livePhotoFileId = metadataFirst.fileId
        }
        let resultsMetadataLast = await NextcloudKit.shared.setLivephoto(serverUrlfileNamePath: serverUrlfileNamePathLast, livePhotoFile: livePhotoFileId, account: metadataLast.account)
        if resultsMetadataLast.error == .success {
            database.setMetadataLivePhotoByServer(account: metadataLast.account, ocId: metadataLast.ocId, livePhotoFile: livePhotoFileId, sync: false)
        }

        if resultsMetadataFirst.error == .success, resultsMetadataLast.error == .success {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload set LivePhoto for files " + (metadataFirst.fileName as NSString).deletingPathExtension)
            notifyAllDelegates { delegate in
               delegate.transferChange(status: self.global.networkingStatusUploadedLivePhoto,
                                       metadata: tableMetadata(value: metadataFirst),
                                       error: .success)
            }
        } else {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Upload set LivePhoto with error \(resultsMetadataFirst.error.errorCode) - \(resultsMetadataLast.error.errorCode)")
        }
    }
}
