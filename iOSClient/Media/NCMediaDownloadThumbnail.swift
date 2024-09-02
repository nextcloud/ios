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
    var metadata: tableMetadata
    var collectioView: UICollectionView?
    var fileNamePreviewLocalPath: String
    var fileNameIconLocalPath: String
    let utilityFileSystem = NCUtilityFileSystem()
    let delegate: NCMedia?

    init(metadata: tableMetadata, collectioView: UICollectionView?, delegate: NCMedia?) {
        self.metadata = tableMetadata.init(value: metadata)
        self.collectioView = collectioView
        self.fileNamePreviewLocalPath = utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
        self.fileNameIconLocalPath = utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
        self.delegate = delegate
    }

    override func start() {
        guard !isCancelled else { return self.finish() }
        var etagResource: String?
        let sizePreview = NCUtility().getSizePreview(width: metadata.width, height: metadata.height)

        if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
            etagResource = metadata.etagResource
        }

        NextcloudKit.shared.downloadPreview(fileId: metadata.fileId,
                                            fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                                            fileNameIconLocalPath: fileNameIconLocalPath,
                                            widthPreview: Int(sizePreview.width),
                                            heightPreview: Int(sizePreview.height),
                                            sizeIcon: NCGlobal.shared.sizeIcon,
                                            etag: etagResource,
                                            account: metadata.account) { _, imagePreview, _, _, etag, error in
            if error == .success, let imagePreview, let collectionView = self.collectioView {

                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                NCImageCache.shared.addPreviewImageCache(metadata: self.metadata, image: imagePreview)

                for case let cell as NCGridMediaCell in collectionView.visibleCells {
                    if cell.ocId == self.metadata.ocId {
                        UIView.transition(with: cell.imageItem,
                                          duration: 0.75,
                                          options: .transitionCrossDissolve,
                                          animations: { cell.imageItem.image = imagePreview },
                                          completion: nil)
                        break
                    }
                }
            }
            self.finish()
        }
    }

    override func finish(success: Bool = true) {
        super.finish(success: success)
        if (metadata.width == 0 && metadata.height == 0) || (NCNetworking.shared.downloadThumbnailQueue.operationCount == 0) {
            self.delegate?.collectionViewReloadData()
        }
    }
}
