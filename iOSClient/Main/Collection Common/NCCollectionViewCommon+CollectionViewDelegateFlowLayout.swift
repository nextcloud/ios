//
//  NCCollectionViewCommon+CollectionViewDelegateFlowLayout.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/07/24.
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

import Foundation
import UIKit

extension NCCollectionViewCommon: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        var height: CGFloat = 0

        if isEditMode {
            return CGSize.zero
        } else if dataSource.getMetadataSourceForAllSections().isEmpty {
            height = NCGlobal.shared.getHeightHeaderEmptyData(view: view, portraitOffset: emptyDataPortaitOffset, landscapeOffset: emptyDataLandscapeOffset, isHeaderMenuTransferViewEnabled: isHeaderMenuTransferViewEnabled())
        } else {
            let (heightHeaderCommands, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: section)
            height = heightHeaderCommands + heightHeaderRichWorkspace + heightHeaderSection
        }
        return CGSize(width: collectionView.frame.width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let sections = dataSource.numberOfSections()
        let metadataForSection = self.dataSource.getMetadataForSection(section)
        let isPaginated = metadataForSection?.lastSearchResult?.isPaginated ?? false
        let metadatasCount: Int = metadataForSection?.lastSearchResult?.entries.count ?? 0
        var size = CGSize(width: collectionView.frame.width, height: 0)

        if section == sections - 1 {
            size.height += NCGlobal.shared.endHeightFooter
        } else {
            size.height += NCGlobal.shared.heightFooter
        }

        if isSearchingMode && isPaginated && metadatasCount > 0 {
            size.height += NCGlobal.shared.heightFooterButton
        }
        return size
    }
}
