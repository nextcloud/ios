//
//  NCFavorite.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/08/2020.
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

class NCFavorite: NCCollectionViewCommon  {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        appDelegate.activeFavorite = self
        titleCurrentFolder = NSLocalizedString("_favorites_", comment: "")
        layoutKey = k_layout_view_favorite
        enableSearchBar = true
        DZNimage = CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 300, height: 300, color: NCBrandColor.sharedInstance.yellowFavorite)
        DZNtitle = "_favorite_no_files_"
        DZNdescription = "_tutorial_favorite_view_"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if serverUrl == "" {
            appDelegate.activeServerUrl = NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        } else {
            appDelegate.activeServerUrl = self.serverUrl
        }
        
        super.viewWillAppear(animated)
    }
    
    // MARK: - DataSource + NC Endpoint
    
    override func reloadDataSource() {
        super.reloadDataSource()
        
        var sort: String
        var ascending: Bool
        var directoryOnTop: Bool
        
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey)
        
        if !isSearching {
       
            if serverUrl == "" {
                metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND favorite == true", appDelegate.account))
            } else {
                metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
            }
        }
        
        self.dataSource = NCDataSource.init(metadatasSource: metadatasSource, sort: sort, ascending: ascending, directoryOnTop: directoryOnTop, filterLivePhoto: true)
        
        refreshControl.endRefreshing()
        collectionView.reloadData()
    }
    
    override func reloadDataSourceNetwork(forced: Bool = false) {
        super.reloadDataSourceNetwork(forced: forced)
        
        if isSearching {
            networkSearch()
            return
        }
        
        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()
        
        if serverUrl == "" {
            
            NCNetworking.shared.listingFavoritescompletion(selector: selectorListingFavorite) { (account, metadatas, errorCode, errorDescription) in
                if errorCode == 0 {
                    for metadata in metadatas ?? [] {
                        if !metadata.directory && CCUtility.getFavoriteOffline() {
                            let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                            if localFile == nil || localFile?.etag != metadata.etag {
                                NCOperationQueue.shared.download(metadata: metadata, selector: selectorDownloadFile, setFavorite: false)
                            }
                        }
                    }
                } else {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
                self.isReloadDataSourceNetworkInProgress = false
                self.reloadDataSource()
            }
            
        } else {
            
            networkReadFolder(forced: forced) { (metadatas, errorCode, errorDescription) in
                if errorCode == 0 {
                    for metadata in metadatas ?? [] {
                        if !metadata.directory {
                            let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                            if (CCUtility.getFavoriteOffline() && localFile == nil) || (localFile != nil && localFile?.etag != metadata.etag) {
                                NCOperationQueue.shared.download(metadata: metadata, selector: selectorDownloadFile, setFavorite: false)
                            }
                        }
                    }
                }
                self.isReloadDataSourceNetworkInProgress = false
                self.reloadDataSource()
            }
        }
    }
}

