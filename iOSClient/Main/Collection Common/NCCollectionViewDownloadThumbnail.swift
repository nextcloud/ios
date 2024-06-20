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
import Queuer
import NextcloudKit
import Realm

class NCCollectionViewDownloadThumbnail: ConcurrentOperation {

    var metadata: tableMetadata
    var cell: NCCellProtocol?
    var collectionView: UICollectionView?
    var fileNamePreviewLocalPath: String
    var fileNameIconLocalPath: String
    let utilityFileSystem = NCUtilityFileSystem()

    init(metadata: tableMetadata, cell: NCCellProtocol?, collectionView: UICollectionView?) {
        self.metadata = tableMetadata.init(value: metadata)
        self.cell = cell
        self.collectionView = collectionView
        self.fileNamePreviewLocalPath = utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
        self.fileNameIconLocalPath = utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
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
                                            widthPreview: Int(sizePreview.width),
                                            heightPreview: Int(sizePreview.height),
                                            fileNameIconLocalPath: fileNameIconLocalPath,
                                            sizeIcon: NCGlobal.shared.sizeIcon,
                                            etag: etagResource,
                                            options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, _, imageIcon, _, etag, error in

            if error == .success, let image = imageIcon {
                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                DispatchQueue.main.async {
                    if self.metadata.ocId == self.cell?.fileObjectId, let filePreviewImageView = self.cell?.filePreviewImageView {
                        if self.metadata.hasPreviewBorder {
                            self.cell?.filePreviewImageView?.layer.borderWidth = 0.2
                            self.cell?.filePreviewImageView?.layer.borderColor = UIColor.systemGray3.cgColor
                        }
                        UIView.transition(with: filePreviewImageView,
                                          duration: 0.75,
                                          options: .transitionCrossDissolve,
                                          animations: { filePreviewImageView.image = image },
                                          completion: nil)
                    } else {
                        self.collectionView?.reloadData()
                    }
                }
            }
            self.finish()
        }
    }
}
