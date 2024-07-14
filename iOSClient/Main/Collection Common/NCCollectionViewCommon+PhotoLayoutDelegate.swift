//
//  File.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import NextcloudKit

extension NCCollectionViewCommon: NCMediaLayoutDelegate {
    func getColumnCount() -> Int {
        NCKeychain().photoColumnCount
    }

    func getLayout() -> String? {
        return NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: NCGlobal.shared.layoutViewFiles, serverUrl: serverUrl)?.layout
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, heightForHeaderInSection section: Int) -> Float {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, heightForFooterInSection section: Int) -> Float {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForSection section: Int) -> UIEdgeInsets {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForHeaderInSection section: Int) -> UIEdgeInsets {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForFooterInSection section: Int) -> UIEdgeInsets {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, minimumInteritemSpacingForSection section: Int) -> Float {
        return 1.0
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath, columnCount: Int, typeLayout: String) -> CGSize {
        var size = CGSize(width: collectionView.frame.width / CGFloat(columnCount), height: collectionView.frame.width / CGFloat(columnCount))
        if typeLayout == NCGlobal.shared.layoutPhotoRatio {
            let metadata = self.dataSource.metadatas[indexPath.row]
            if metadata.imageSize != CGSize.zero {
                return metadata.imageSize
            } else {
                let existsIcon = utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)
                if let image = NCImageCache.shared.getMediaImage(ocId: metadata.ocId, etag: metadata.etag) {
                    size = image.size
                } else if let image = UIImage(contentsOfFile: self.utilityFileSystem.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)) {
                    size = image.size
                }
            }
        }
        return size
    }
}
