//
//  NCShares.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import NCCommunication

class NCShares: NCCollectionViewCommon  {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        appDelegate.activeShares = self
        titleCurrentFolder = NSLocalizedString("_list_shares_", comment: "")
        layoutKey = k_layout_view_shares
        enableSearchBar = false
        emptyImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 300, height: 300, color: NCBrandColor.sharedInstance.yellowFavorite)
        emptyTitle = "_list_shares_no_files_"
        emptyDescription = "_tutorial_list_shares_view_"
    }
    
    // MARK: - DataSource + NC Endpoint
    
    override func reloadDataSource() {
        super.reloadDataSource()
        
        self.metadatasSource.removeAll()
        let sharess = NCManageDatabase.sharedInstance.getTableShares(account: appDelegate.account)
        for share in sharess {
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", appDelegate.account, share.serverUrl, share.fileName)) {
                self.metadatasSource.append(metadata)
            }
        }
        
        self.dataSource = NCDataSource.init(metadatasSource: self.metadatasSource, sort:self.sort, ascending: self.ascending, directoryOnTop: self.directoryOnTop, favoriteOnTop: true, filterLivePhoto: true)
        
        self.refreshControl.endRefreshing()
        self.collectionView.reloadData()
    }
    
    override func reloadDataSourceNetwork(forced: Bool = false) {
        super.reloadDataSourceNetwork(forced: forced)
    }
}

