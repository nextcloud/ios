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
    func createLivePhoto(metadata: tableMetadata) async {
        let predicate = NSPredicate(format: "account == %@ AND urlBase == %@ AND path == %@ AND fileNameView == %@",
                                    metadata.account,
                                    metadata.urlBase,
                                    metadata.path,
                                    metadata.livePhotoFile)

        let metadataLast = await NCManageDatabase.shared.getMetadataAsync(predicate: predicate)

        if let metadataLast {
            if metadataLast.status != self.global.metadataStatusNormal {
                return nkLog(debug: "Upload set LivePhoto error for files (NO Status Normal) " + (metadataLast.fileName as NSString).deletingPathExtension)
            }

            await self.setLivePhoto(metadataFirst: metadata, metadataLast: metadataLast)

        } else {
            metadata.livePhotoFile = ""
            await NCManageDatabase.shared.addMetadataAsync(metadata)
            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusUploadedLivePhoto,
                                        metadata: metadata,
                                        error: .success)
            }
        }
    }

    func setLivePhoto(metadataFirst: tableMetadata?, metadataLast: tableMetadata?, livePhoto: Bool = true) async {
        guard let metadataFirst, let metadataLast = metadataLast else { return }
        var livePhotoFileId = ""

        /// METADATA FIRST
        let serverUrlfileNamePathFirst = metadataFirst.urlBase + metadataFirst.path + metadataFirst.fileName
        if livePhoto {
            livePhotoFileId = metadataLast.fileId
        }
        let resultsMetadataFirst = await NextcloudKit.shared.setLivephotoAsync(serverUrlfileNamePath: serverUrlfileNamePathFirst, livePhotoFile: livePhotoFileId, account: metadataFirst.account)
        if resultsMetadataFirst.error == .success {
            await NCManageDatabase.shared.setMetadataLivePhotoByServerAsync(account: metadataFirst.account, ocId: metadataFirst.ocId, livePhotoFile: livePhotoFileId)
        }

        ///  METADATA LAST
        let serverUrlfileNamePathLast = metadataLast.urlBase + metadataLast.path + metadataLast.fileName
        if livePhoto {
            livePhotoFileId = metadataFirst.fileId
        }
        let resultsMetadataLast = await NextcloudKit.shared.setLivephotoAsync(serverUrlfileNamePath: serverUrlfileNamePathLast, livePhotoFile: livePhotoFileId, account: metadataLast.account)
        if resultsMetadataLast.error == .success {
            await NCManageDatabase.shared.setMetadataLivePhotoByServerAsync(account: metadataLast.account, ocId: metadataLast.ocId, livePhotoFile: livePhotoFileId)
        }

        if resultsMetadataFirst.error == .success, resultsMetadataLast.error == .success {
            nkLog(debug: "Upload set LivePhoto for files " + (metadataFirst.fileName as NSString).deletingPathExtension)
            await self.transferDispatcher.notifyAllDelegates { delegate in
               delegate.transferChange(status: self.global.networkingStatusUploadedLivePhoto,
                                       metadata: metadataFirst,
                                       error: .success)
            }
        } else {
            nkLog(error: "Upload set LivePhoto with error \(resultsMetadataFirst.error.errorCode) - \(resultsMetadataLast.error.errorCode)")
        }
    }
}
