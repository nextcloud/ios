//
//  NCFiles.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/09/2020.
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

class NCFiles: NCCollectionViewCommon  {
    
    internal var isRoot: Bool = true

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        appDelegate.activeFiles = self
        titleCurrentFolder = NCBrandOptions.sharedInstance.brand
        layoutKey = k_layout_view_files
        enableSearchBar = true
        emptyImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 300, height: 300, color: NCBrandColor.sharedInstance.brandElement)
        emptyTitle = "_files_no_files_"
        emptyDescription = "_no_file_pull_down_"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        if isRoot {
            serverUrl = NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        }
        
        super.viewWillAppear(animated)
    }
    
    // MARK: - NotificationCenter
    
    override func initializeMain() {
        
        if isRoot {
            serverUrl = NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
            reloadDataSourceNetwork(forced: true)
        }
        
        super.initializeMain()
    }
    
    // MARK: - DataSource + NC Endpoint
    
    override func reloadDataSource() {
        super.reloadDataSource()
        
        DispatchQueue.global().async {
                        
            if !self.isSearching {
                self.metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
                if self.metadataFolder == nil {
                    self.metadataFolder = NCManageDatabase.sharedInstance.getMetadataFolder(account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, serverUrl:  self.serverUrl)
                }
            }
            
            self.dataSource = NCDataSource.init(metadatasSource: self.metadatasSource, sort: self.sort, ascending: self.ascending, directoryOnTop: self.directoryOnTop, favoriteOnTop: true, filterLivePhoto: true)
            
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
                
                self.empty?.reload()
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
               
        networkReadFolder(forced: forced) { (metadatas, metadatasUpdate, errorCode, errorDescription) in
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
            
            self.refreshControl.endRefreshing()
            self.isReloadDataSourceNetworkInProgress = false
            if metadatasUpdate?.count ?? 0 > 0 || forced {
                self.reloadDataSource()
            } else {
                self.collectionView?.reloadData()
            }
        }
    }
}

