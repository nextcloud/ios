//
//  NCCollectionViewDownloadThumbnail.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/03/24.
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

import Foundation
import UIKit
import Queuer
import NextcloudKit
import RealmSwift

class NCCollectionViewDownloadThumbnail: ConcurrentOperation, @unchecked Sendable {
    var metadata: tableMetadata
    var collectionView: UICollectionView?
    var ext = ""
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    init(metadata: tableMetadata, collectionView: UICollectionView?, ext: String) {
        self.metadata = tableMetadata.init(value: metadata)
        self.collectionView = collectionView
        self.ext = ext
    }

    override func start() {
        guard !isCancelled else { return self.finish() }
        var etagResource: String?

        if utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag) {
            etagResource = metadata.etagResource
        }

        NextcloudKit.shared.downloadPreview(fileId: metadata.fileId,
                                            etag: etagResource,
                                            account: self.metadata.account,
                                            options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, _, _, etag, responseData, error in

            if error == .success, let data = responseData?.data, let collectionView = self.collectionView {

                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                NCUtility().createImageFileFrom(data: data, metadata: self.metadata)
                let image = self.utility.getImage(ocId: self.metadata.ocId, etag: self.metadata.etag, ext: self.ext)

                DispatchQueue.main.async {
                    for case let cell as NCCellProtocol in collectionView.visibleCells where cell.fileOcId == self.metadata.ocId {
                        if let filePreviewImageView = cell.filePreviewImageView {
                            filePreviewImageView.contentMode = .scaleAspectFill

                            if self.metadata.hasPreviewBorder {
                                filePreviewImageView.layer.borderWidth = 0.2
                                filePreviewImageView.layer.borderColor = UIColor.systemGray3.cgColor
                            }

                            if let photoCell = (cell as? NCPhotoCell),
                               photoCell.bounds.size.width > 100 {
                                    cell.hideButtonMore(false)
                                    cell.hideImageStatus(false)
                            }

                            UIView.transition(with: filePreviewImageView,
                                              duration: 0.75,
                                              options: .transitionCrossDissolve,
                                              animations: { filePreviewImageView.image = image },
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
