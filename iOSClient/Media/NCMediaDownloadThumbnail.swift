//
//  NCMediaDownloadThumbnail.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/01/24.
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
import Alamofire

class NCMediaDownloadThumbnail: ConcurrentOperation, @unchecked Sendable {
    var metadata: NCMediaDataSource.Metadata
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared
    let media: NCMedia
    var session: NCSession.Session

    init(metadata: NCMediaDataSource.Metadata, media: NCMedia) {
        self.metadata = metadata
        self.media = media
        self.session = media.session
    }

    override func start() {
        guard !isCancelled,
              let tableMetadata = NCManageDatabase.shared.getResultMetadataFromOcId(self.metadata.ocId)?.freeze() else { return self.finish() }
        var etagResource: String?

        if utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag) {
            etagResource = tableMetadata.etagResource
        }

        NextcloudKit.shared.downloadPreview(fileId: tableMetadata.fileId,
                                            etag: etagResource,
                                            account: self.session.account,
                                            options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, _, _, etag, responseData, error in
            if error == .success, let data = responseData?.data {

                self.media.filesExists.append(self.metadata.ocId)
                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                NCUtility().createImageFileFrom(data: data, metadata: tableMetadata)
                let image = NCUtility().getImage(ocId: self.metadata.ocId, etag: self.metadata.etag, ext: NCGlobal.shared.getSizeExtension(column: self.media.numberOfColumns))

                DispatchQueue.main.async {
                    for case let cell as NCMediaCell in self.media.collectionView.visibleCells {
                        if cell.ocId == self.metadata.ocId {
                            UIView.transition(with: cell.imageItem, duration: 0.75, options: .transitionCrossDissolve, animations: { cell.imageItem.image = image
                            }, completion: nil)
                            break
                        }
                    }
                }
            } else if error.errorCode == self.global.errorResourceNotFound {
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterDeleteFile, userInfo: ["ocId": tableMetadata.ocId, "error": error])
            }
            self.finish()
        }
    }
}
