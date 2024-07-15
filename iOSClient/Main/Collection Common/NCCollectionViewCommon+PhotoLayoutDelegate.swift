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
        let size = CGSize(width: collectionView.frame.width / CGFloat(columnCount), height: collectionView.frame.width / CGFloat(columnCount))
        if typeLayout == NCGlobal.shared.layoutPhotoRatio {
            let metadata = self.dataSource.metadatas[indexPath.row]

            if metadata.imageSize != CGSize.zero {
                return metadata.imageSize
            } else if let size = NCImageCache.shared.getPreviewSizeCache(ocId: metadata.ocId, etag: metadata.etag) {
                return size
            }
        }
        return size
    }
}
