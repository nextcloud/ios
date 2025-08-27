// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
        guard !isCancelled else {
            return self.finish()
        }

        Task {
            let resultsPreview = await NextcloudKit.shared.downloadPreviewAsync(fileId: metadata.fileId, etag: metadata.etag, account: metadata.account) { task in
                Task {
                    let identifier = self.metadata.fileId + NCGlobal.shared.taskIdentifierDownloadPreview
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            if resultsPreview.error == .success,
               let data = resultsPreview.responseData?.data,
               let collectionView = self.collectionView {
                NCUtility().createImageFileFrom(data: data, metadata: self.metadata)
                let image = self.utility.getImage(ocId: self.metadata.ocId, etag: self.metadata.etag, ext: self.ext, userId: self.metadata.userId, urlBase: self.metadata.urlBase)

                Task { @MainActor in
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
