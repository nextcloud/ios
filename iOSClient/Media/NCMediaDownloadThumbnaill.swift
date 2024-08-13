//
//  NCMediaDownloadThumbnaill.swift
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

class NCMediaDownloadThumbnaill: ConcurrentOperation {
    var metadata: tableMetadata
    var media: NCMedia
    var fileNamePreviewLocalPath: String
    var fileNameIconLocalPath: String
    let utilityFileSystem = NCUtilityFileSystem()

    init(metadata: tableMetadata, media: NCMedia) {
        self.metadata = tableMetadata.init(value: metadata)
        self.media = media
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
                                            fileNameIconLocalPath: fileNameIconLocalPath,
                                            widthPreview: Int(sizePreview.width),
                                            heightPreview: Int(sizePreview.height),
                                            sizeIcon: NCGlobal.shared.sizeIcon,
                                            etag: etagResource,
                                            account: metadata.account,
                                            options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, imagePreview, _, _, etag, error in
            if error == .success, let imagePreview {
                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                DispatchQueue.main.async {
                    if let visibleCells = self.media.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.media.collectionView?.cellForItem(at: $0) }) {
                        for case let cell as NCGridMediaCell in visibleCells {
                            if cell.ocId == self.metadata.ocId, let imageItem = cell.imageItem {
                                UIView.transition(with: imageItem,
                                                  duration: 0.75,
                                                  options: .transitionCrossDissolve,
                                                  animations: { imageItem.image = imagePreview },
                                                  completion: nil)
                                break
                            }
                        }
                    }
                }
                NCImageCache.shared.addPreviewImageCache(metadata: self.metadata, image: imagePreview)
            }
            self.finish()
        }
    }

    override func finish(success: Bool = true) {
        super.finish(success: success)
        if (metadata.width == 0 && metadata.height == 0) || (NCNetworking.shared.downloadThumbnailQueue.operationCount == 0) {
            self.media.collectionViewReloadData()
        }
    }
}
