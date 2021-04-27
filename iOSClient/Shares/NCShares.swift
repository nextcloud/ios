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
    
    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        titleCurrentFolder = NSLocalizedString("_list_shares_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewShares 
        enableSearchBar = false
        emptyImage = UIImage.init(named: "share")?.image(color: .gray, size: UIScreen.main.bounds.width)
        emptyTitle = "_list_shares_no_files_"
        emptyDescription = "_tutorial_list_shares_view_"
    }
    
    // MARK: - DataSource + NC Endpoint
    
    override func reloadDataSource() {
        super.reloadDataSource()
        
        DispatchQueue.global().async {
            self.metadatasSource.removeAll()
            let sharess = NCManageDatabase.shared.getTableShares(account: self.appDelegate.account)
            for share in sharess {
                if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", self.appDelegate.account, share.serverUrl, share.fileName)) {
                    self.metadatasSource.append(metadata)
                }
            }
            
            self.dataSource = NCDataSource.init(metadatasSource: self.metadatasSource, sort:self.sort, ascending: self.ascending, directoryOnTop: self.directoryOnTop, favoriteOnTop: true, filterLivePhoto: true)
            
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
            }
        }
    }
    
    override func reloadDataSourceNetwork(forced: Bool = false) {
        super.reloadDataSourceNetwork(forced: forced)
        
        if isSearching {
            networkSearch()
            return
        }
                
        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()
                    
        // Shares network
        NCCommunication.shared.readShares { (account, shares, errorCode, ErrorDescription) in
                
            self.refreshControl.endRefreshing()
            self.isReloadDataSourceNetworkInProgress = false
                
            if errorCode == 0 {
                    
                NCManageDatabase.shared.deleteTableShare(account: account)
                if shares != nil {
                    NCManageDatabase.shared.addShare(urlBase: self.appDelegate.urlBase, account: account, shares: shares!)
                }
                self.appDelegate.shares = NCManageDatabase.shared.getTableShares(account: account)
                    
                self.reloadDataSource()
                    
            } else {
                    
                self.collectionView?.reloadData()
                NCContentPresenter.shared.messageNotification("_share_", description: ErrorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
}

