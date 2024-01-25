//
//  NCMediaDownloadThumbnaill.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/01/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import UIKit
import NextcloudKit
import Queuer

class NCMediaDownloadThumbnaill: ConcurrentOperation {

    var metadata: tableMetadata
    var collectionView: UICollectionView?
    var fileNamePath: String
    var fileNamePreviewLocalPath: String
    var fileNameIconLocalPath: String
    let utilityFileSystem = NCUtilityFileSystem()

    init(metadata: tableMetadata, collectionView: UICollectionView?) {
        self.metadata = tableMetadata.init(value: metadata)
        self.collectionView = collectionView
        self.fileNamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)
        self.fileNamePreviewLocalPath = utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
        self.fileNameIconLocalPath = utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
    }

    override func start() {

        guard !isCancelled else { return self.finish() }

        var etagResource: String?
        if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
            etagResource = metadata.etagResource
        }

        NextcloudKit.shared.downloadPreview(fileNamePathOrFileId: fileNamePath,
                                            fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                                            widthPreview: NCGlobal.shared.sizePreview,
                                            heightPreview: NCGlobal.shared.sizePreview,
                                            fileNameIconLocalPath: fileNameIconLocalPath,
                                            sizeIcon: NCGlobal.shared.sizeIcon,
                                            etag: etagResource,
                                            options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, imagePreview, _, _, etag, error in

            if error == .success, let image = imagePreview {
                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                DispatchQueue.main.async {
                    if let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) }) {
                        for case let cell as NCGridMediaCell in visibleCells {
                            if cell.fileObjectId == self.metadata.ocId, let filePreviewImageView = cell.filePreviewImageView {
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
                NCImageCache.shared.setMediaImage(ocId: self.metadata.ocId, etag: self.metadata.etag, image: .actual(image))
            }
            self.finish()
        }
    }
}
