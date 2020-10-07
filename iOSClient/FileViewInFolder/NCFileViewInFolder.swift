//
//  NCFileViewInFolder.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/10/2020.
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

class NCFileViewInFolder: NCCollectionViewCommon  {
    
    internal var fileName: String?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        appDelegate.activeFileViewInFolder = self
        layoutKey = k_layout_view_viewInFolder
        enableSearchBar = false
        DZNimage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 300, height: 300, color: NCBrandColor.sharedInstance.brandElement)
        DZNtitle = "_files_no_files_"
        DZNdescription = "_no_file_pull_down_"
    }
    
    override func viewWillAppear(_ animated: Bool) {
                
        if serverUrl == NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account) {
            self.navigationItem.title = NCBrandOptions.sharedInstance.brand
        } else {
            self.navigationItem.title = CCUtility.getLastPath(fromServerUrl: serverUrl, urlBase: appDelegate.urlBase)
        }
        
        presentationController?.delegate = self
        appDelegate.activeViewController = self
        
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(itemForLine)
        
        if layout == k_layout_list {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }

        self.navigationItem.leftBarButtonItem = nil
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .plain, target: self, action: #selector(tapClose(sender:)))       
    }

    // MARK: - TAP EVENT

    @objc func tapClose(sender: Any) {
        dismiss(animated: true) {
            self.appDelegate.activeFileViewInFolder = nil
        }
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
                
                // Blink file
                if self.fileName != nil {
                    if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", self.appDelegate.account, self.serverUrl, self.fileName!)) {
                        if let row = self.dataSource.getIndexMetadata(ocId: metadata.ocId) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                UIView.animate(withDuration: 0.3) {
                                    self.collectionView.scrollToItem(at: IndexPath(row: row, section: 0), at: .centeredVertically, animated: false)
                                } completion: { (_) in
                                    if let cell = self.collectionView.cellForItem(at: IndexPath(row: row, section: 0)) {
                                        NCUtility.shared.blink(cell: cell)
                                        self.fileName = nil
                                    }
                                }
                            }
                        }
                    }
                }
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
            self.reloadDataSource()
        }
    }
}

