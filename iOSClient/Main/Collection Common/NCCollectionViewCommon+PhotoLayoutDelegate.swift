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

extension NCCollectionViewCommon: NCPhotoLayoutDelegate {
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
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath, columnCount: Int, typeLayout: String) -> CGSize {
        var size = CGSize(width: collectionView.frame.width / CGFloat(columnCount), height: collectionView.frame.width / CGFloat(columnCount))
        if typeLayout == NCGlobal.shared.layoutPhotoRatio {
            let metadata = self.dataSource.metadatas[indexPath.row]
            if metadata.imageSize != CGSize.zero {
                return metadata.imageSize
            } else if utilityFileSystem.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag),
                   let image = utility.createFilePreviewImage(ocId: metadata.ocId, etag: metadata.etag, fileNameView: metadata.fileNameView, classFile: metadata.classFile, status: metadata.status, createPreviewMedia: !metadata.hasPreview) {
                    size = image.size
            }
        }
        return size
    }
}
