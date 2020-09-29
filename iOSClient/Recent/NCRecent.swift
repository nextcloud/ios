//
//  NCRecent.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/09/2020.
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

class NCRecent: NCCollectionViewCommon  {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        appDelegate.activeRecent = self
        titleCurrentFolder = NSLocalizedString("_recent_", comment: "")
        layoutKey = k_layout_view_recent
        enableSearchBar = true
        DZNimage = CCGraphics.changeThemingColorImage(UIImage.init(named: "recent"), width: 300, height: 300, color: NCBrandColor.sharedInstance.brandElement)
        DZNtitle = "_files_no_files_"
        DZNdescription = ""
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    // MARK: - DataSource + NC Endpoint
    
    override func reloadDataSource() {
        super.reloadDataSource()
        
        var sort: String
        var ascending: Bool
        var directoryOnTop: Bool
        
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: "")
        
        metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@", appDelegate.account), limit: 100, sorted: "date", ascending: true)
        self.dataSource = NCDataSource.init(metadatasSource: metadatasSource, sort: sort, ascending: ascending, directoryOnTop: directoryOnTop, filterLivePhoto: true)
        
        refreshControl.endRefreshing()
        collectionView.reloadData()
    }
    
    override func reloadDataSourceNetwork(forced: Bool = false) {
        super.reloadDataSourceNetwork(forced: forced)
        
        self.refreshControl.endRefreshing()
        self.isReloadDataSourceNetworkInProgress = false
        self.reloadDataSource()
    }
}

