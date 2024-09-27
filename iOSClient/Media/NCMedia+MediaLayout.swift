//
//  NCMedia+MediaLayout.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  NCMedia+CollectionViewDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/07/24.
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
import RealmSwift

extension NCMedia: NCMediaLayoutDelegate {
    func getColumnCount() -> Int {
        if self.numberOfColumns == 0,
           let layoutForView = database.getLayoutForView(account: session.account, key: global.layoutViewMedia, serverUrl: "") {
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
        var height: Double = 0
        if dataSource.metadatas.count == 0 {
            height = utility.getHeightHeaderEmptyData(view: view, portraitOffset: 0, landscapeOffset: -20)
        }
        return Float(height)
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, heightForFooterInSection section: Int) -> Float {
        if dataSource.metadatas.count == 0 {
            return .zero
        } else {
            return 70.0
        }
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
        if typeLayout == global.mediaLayoutSquare {
            return CGSize(width: collectionView.frame.width / CGFloat(columnCount), height: collectionView.frame.width / CGFloat(columnCount))
        } else {
            guard let metadata = dataSource.getMetadata(indexPath: indexPath) else { return .zero }

            if metadata.imageSize != CGSize.zero {
                return metadata.imageSize
            } else {
                return CGSize(width: collectionView.frame.width / CGFloat(columnCount), height: collectionView.frame.width / CGFloat(columnCount))
            }
        }
    }
}
