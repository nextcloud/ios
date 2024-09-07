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
    let utilityFileSystem = NCUtilityFileSystem()
    let delegate: NCMedia?

    init(metadata: tableMetadata, collectioView: UICollectionView?, delegate: NCMedia?) {
        self.metadata = tableMetadata.init(value: metadata)
        self.collectioView = collectioView
        self.delegate = delegate
    }

    override func start() {
        guard !isCancelled else { return self.finish() }
        var etagResource: String?
        let size = NCUtility().getSize1024(width: metadata.width, height: metadata.height)

        if utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag) {
            etagResource = metadata.etagResource
        }

        NextcloudKit.shared.downloadPreview(fileId: metadata.fileId,
                                            width: Int(size.width),
                                            height: Int(size.height),
                                            etag: etagResource,
                                            account: metadata.account,
                                            options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, data, _, _, etag, error in
            if error == .success, let data, let collectionView = self.collectioView {

                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                NCUtility().createImage(ocId: self.metadata.ocId, etag: self.metadata.etag, classFile: self.metadata.classFile, data: data, cacheMetadata: self.metadata)

                DispatchQueue.main.async {
                    for case let cell as NCGridMediaCell in collectionView.visibleCells {
                        let ext = NCGlobal.shared.getSizeExtension(width: cell.imageItem?.bounds.size.width)
                        if cell.ocId == self.metadata.ocId,
                           let image = NCUtility().getImage(ocId: self.metadata.ocId, etag: self.metadata.etag, ext: ext) {
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
