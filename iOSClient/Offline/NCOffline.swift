//
//  NCOffline.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

class NCOffline: NCCollectionViewCommon  {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        appDelegate.activeOffline = self
        titleCurrentFolder = NSLocalizedString("_manage_file_offline_", comment: "")
        layoutKey = k_layout_view_offline
        enableSearchBar = true
        emptyImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 300, height: 300, color: NCBrandColor.sharedInstance.brandElement)
        emptyTitle = "_files_no_files_"
        emptyDescription = "_tutorial_offline_view_"
    }
    
    // MARK: - DataSource + NC Endpoint

    override func reloadDataSource() {
        super.reloadDataSource()
              
        DispatchQueue.global().async {
            
            var ocIds: [String] = []
            
            if !self.isSearching {
                
                if self.serverUrl == "" {
                   
                    if let directories = NCManageDatabase.sharedInstance.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", self.appDelegate.account), sorted: "serverUrl", ascending: true) {
                        for directory: tableDirectory in directories {
                            ocIds.append(directory.ocId)
                        }
                    }
                   
                    let files = NCManageDatabase.sharedInstance.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", self.appDelegate.account), sorted: "fileName", ascending: true)
                    for file: tableLocalFile in files {
                        ocIds.append(file.ocId)
                    }
                   
                    self.metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND ocId IN %@", self.appDelegate.account, ocIds))
                    
                } else {
                   
                    self.metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
                }
            }
            
            self.dataSource = NCDataSource.init(metadatasSource: self.metadatasSource, sort: self.sort, ascending: self.ascending, directoryOnTop: self.directoryOnTop, favoriteOnTop: true, filterLivePhoto: true)
            
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
                    
        if serverUrl == "" {
            
            self.reloadDataSource()
            
        } else {
           
            isReloadDataSourceNetworkInProgress = true
            collectionView?.reloadData()
            
            networkReadFolder(forced: forced) { (metadatas, metadatasUpdate, errorCode, errorDescription) in
                if errorCode == 0 {
                    for metadata in metadatas ?? [] {
                        if !metadata.directory {
                            let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                            if localFile == nil || localFile?.etag != metadata.etag {
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
}
