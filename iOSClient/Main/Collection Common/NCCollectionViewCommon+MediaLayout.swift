// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

extension NCCollectionViewCommon: NCMediaLayoutDelegate {
    func getColumnCount() -> Int {
        if self.numberOfColumns == 0 {
            let layoutForView = database.getLayoutForView(account: session.account, key: global.layoutViewFiles, serverUrl: self.serverUrl)
            if layoutForView.columnPhoto > 0 {
                self.numberOfColumns = layoutForView.columnPhoto
            } else {
                self.numberOfColumns = 3
            }
        }
        return self.numberOfColumns
    }

    func getLayout() -> String? {
        return self.layoutType
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, heightForHeaderInSection section: Int) -> Float {
        return Float(sizeForHeaderInSection(section: section).height)
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, heightForFooterInSection section: Int) -> Float {
        return Float(sizeForFooterInSection(section: section).height)
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

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath, columnCount: Int, typeLayout: String) -> CGSize {
        if typeLayout == global.layoutPhotoSquare {
            return CGSize(width: collectionView.frame.width / CGFloat(columnCount), height: collectionView.frame.width / CGFloat(columnCount))
        } else {
            guard let metadata = dataSource.getMetadata(indexPath: indexPath) else { return .zero }

            if metadata.imageSize != CGSize.zero {
                return metadata.imageSize
            } else if metadata.classFile == NKTypeClassFile.document.rawValue {
                let ext = global.getSizeExtension(column: self.numberOfColumns)
                if let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase) {
                    return image.size
                }
            }

            return CGSize(width: collectionView.frame.width / CGFloat(columnCount), height: collectionView.frame.width / CGFloat(columnCount))
        }
    }
}
