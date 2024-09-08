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

class NCMediaDownloadThumbnail: ConcurrentOperation {
    var metadata: NCMediaDataSource.Metadata
    var collectionView: UICollectionView?
    let utilityFileSystem = NCUtilityFileSystem()
    let delegate: NCMedia?
    var ext = ""

    init(metadata: NCMediaDataSource.Metadata, collectionView: UICollectionView?, delegate: NCMedia?) {
        self.metadata = metadata
        self.collectionView = collectionView
        self.delegate = delegate

        if let collectionView, let columnPhoto = delegate?.columnPhoto {
            let width = collectionView.frame.size.width / CGFloat(columnPhoto)
            ext = NCGlobal.shared.getSizeExtension(width: width)
        }
    }

    override func start() {
        guard !isCancelled else { return self.finish() }
        var etagResource: String?

        if utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag) {
            etagResource = metadata.etagResource
        }

        NextcloudKit.shared.downloadPreview(fileId: metadata.fileId,
                                            etag: etagResource,
                                            account: metadata.account,
                                            options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, data, _, _, etag, error in
            if error == .success, let data, let collectionView = self.collectionView {

                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                if let metadata = NCManageDatabase.shared.getMetadataFromOcId(self.metadata.ocId) {
                    NCUtility().createImage(ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile, data: data)
                }

                DispatchQueue.main.async {
                    for case let cell as NCGridMediaCell in collectionView.visibleCells {
                        if cell.ocId == self.metadata.ocId,
                           let image = NCUtility().getImage(ocId: self.metadata.ocId, etag: self.metadata.etag, ext: self.ext) {
                            UIView.transition(with: cell.imageItem,
                                              duration: 0.75,
                                              options: .transitionCrossDissolve,
                                              animations: { cell.imageItem.image = image },
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
