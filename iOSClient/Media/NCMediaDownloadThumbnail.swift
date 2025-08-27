// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Queuer

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
       Task {
           guard !isCancelled,
                 let tblMetadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(self.metadata.ocId) else {
               return self.finish()
           }
           var image: UIImage?

           let resultsDownloadPreview = await NextcloudKit.shared.downloadPreviewAsync(fileId: tblMetadata.fileId, etag: tblMetadata.etag, account: tblMetadata.account, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { task in
               Task {
                   let identifier = tblMetadata.account + "_" + tblMetadata.fileId + NCGlobal.shared.taskIdentifierDownloadPreview
                   await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
               }
           }

           if resultsDownloadPreview.error == .success, let data = resultsDownloadPreview.responseData?.data {
               NCUtility().createImageFileFrom(data: data, metadata: tblMetadata)

               image = await NCUtility().getImage(ocId: tblMetadata.ocId, etag: tblMetadata.etag, ext: NCGlobal.shared.getSizeExtension(column: self.media.numberOfColumns), userId: tblMetadata.userId, urlBase: tblMetadata.urlBase)
           }

           Task { @MainActor in
               for case let cell as NCMediaCell in self.media.collectionView.visibleCells {
                   if cell.ocId == tblMetadata.ocId {
                       if image == nil {
                           cell.imageItem.contentMode = .scaleAspectFit
                           image = NCUtility().loadImage(named: tblMetadata.iconName, useTypeIconFile: true, account: tblMetadata.account)
                       } else {
                           cell.imageItem.contentMode = .scaleAspectFill
                       }

                       UIView.transition(with: cell.imageItem, duration: 0.75, options: .transitionCrossDissolve, animations: { cell.imageItem.image = image
                       }, completion: nil)

                       break
                   }
               }
           }

           self.finish()
       }
   }
}
