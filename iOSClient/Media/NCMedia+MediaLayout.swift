// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

extension NCMedia: NCMediaLayoutDelegate {
    func getColumnCount() -> Int {
        if self.numberOfColumns == 0 {
            let layoutForView = database.getLayoutForView(account: session.account, key: global.layoutViewMedia, serverUrl: "")
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
        if dataSource.isEmpty() {
            return section == 0
            ? Float(utility.getHeightHeaderEmptyData(view: view, portraitOffset: 0, landscapeOffset: -20))
            : .zero
          }

          return 80.0
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, heightForFooterInSection section: Int) -> Float {
        guard !dataSource.isEmpty() else {
            return .zero
        }

        return section == dataSource.numberOfSections - 1 ? 100.0 : .zero
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
        let defaultSize = CGSize(
            width: collectionView.bounds.width / CGFloat(columnCount),
            height: collectionView.bounds.width / CGFloat(columnCount)
        )

        guard typeLayout != global.mediaLayoutSquare else {
            return defaultSize
        }

        guard let compactMetadata = dataSource.getCompactMetadata(indexPath: indexPath),
              compactMetadata.imageSize != .zero else {
            return defaultSize
        }

        return compactMetadata.imageSize
    }
}
