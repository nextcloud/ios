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

class NCMediaDownloadThumbnail: ConcurrentOperation, @unchecked Sendable {
    var metadata: NCMediaDataSource.Metadata
    var collectionView: UICollectionView?
    let utilityFileSystem = NCUtilityFileSystem()
    let media: NCMedia?
    var width: CGFloat?
    let cost: Int

    init(metadata: NCMediaDataSource.Metadata, collectionView: UICollectionView?, media: NCMedia?, cost: Int) {
        self.metadata = metadata
        self.collectionView = collectionView
        self.media = media
        self.cost = cost

        if let collectionView, let numberOfColumns = self.media?.numberOfColumns {
            width = collectionView.frame.size.width / CGFloat(numberOfColumns)
        }
    }

    override func start() {
        guard !isCancelled, let tableMetadata = NCManageDatabase.shared.getMetadataFromOcId(self.metadata.ocId), let media = self.media else { return self.finish() }
        var etagResource: String?

        if utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag) {
            etagResource = tableMetadata.etagResource
        }

        NextcloudKit.shared.downloadPreview(fileId: tableMetadata.fileId,
                                            etag: etagResource,
                                            account: media.session.account,
                                            options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, data, _, _, etag, error in
            if error == .success, let data, let collectionView = self.collectionView, let media = self.media {

                media.filesExists.append(self.metadata.ocId)
                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                NCUtility().createImage(metadata: tableMetadata, data: data)

                DispatchQueue.main.async {
                    for case let cell as NCGridMediaCell in collectionView.visibleCells {
                        if cell.ocId == self.metadata.ocId {
                            UIView.transition(with: cell.imageItem,
                                              duration: 0.75,
                                              options: .transitionCrossDissolve,
                                              animations: { cell.imageItem.image = NCUtility().getImage(ocId: self.metadata.ocId, etag: self.metadata.etag, ext: NCGlobal.shared.getSizeExtension(column: media.numberOfColumns)) },
                                              completion: nil)
                            break
                        }
                    }
                }
            }
            self.finish()
        }
    }
}
