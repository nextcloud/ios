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
        DZNimage = "folder"
        DZNtitle = "_files_no_files_"
        DZNdescription = "_tutorial_offline_view_"
    }
    
    // MARK: - Collection View
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let metadata = dataSource?.cellForItemAt(indexPath: indexPath) else { return }
        metadataPush = metadata
        
        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }
        
        if metadata.directory {
            
            guard let serverUrlPush = CCUtility.stringAppendServerUrl(metadataPush!.serverUrl, addFileName: metadataPush!.fileName) else { return }
            let ncOffline:NCOffline = UIStoryboard(name: "NCOffline", bundle: nil).instantiateInitialViewController() as! NCOffline
            
            ncOffline.serverUrl = serverUrlPush
            ncOffline.titleCurrentFolder = metadataPush!.fileNameView
            
            self.navigationController?.pushViewController(ncOffline, animated: true)
            
        } else {
            
            if CCUtility.fileProviderStorageExists(metadataPush?.ocId, fileNameView: metadataPush?.fileNameView) {
                performSegue(withIdentifier: "segueDetail", sender: self)
            } else {
                NCNetworking.shared.download(metadata: metadataPush!, selector: "") { (errorCode) in
                    if errorCode == 0 {
                        self.performSegue(withIdentifier: "segueDetail", sender: self)
                    }
                }
            }
        }
    }
    
    // MARK: - NC API & Algorithm

    override func reloadDataSource() {
           
        var ocIds: [String] = []
        var sort: String
        var ascending: Bool
        var directoryOnTop: Bool
           
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: k_layout_view_offline)

        if !isSearching {
            
            if serverUrl == "" {
               
                if let directories = NCManageDatabase.sharedInstance.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", appDelegate.account), sorted: "serverUrl", ascending: true) {
                    for directory: tableDirectory in directories {
                        ocIds.append(directory.ocId)
                    }
                }
               
                let files = NCManageDatabase.sharedInstance.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", appDelegate.account), sorted: "fileName", ascending: true)
                for file: tableLocalFile in files {
                    ocIds.append(file.ocId)
                }
               
                metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND ocId IN %@", appDelegate.account, ocIds))
                
            } else {
               
                metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
            }
        }
        
        self.dataSource = NCDataSource.init(metadatasSource: metadatasSource, sort: sort, ascending: ascending, directoryOnTop: directoryOnTop, filterLivePhoto: true)
        
        refreshControl.endRefreshing()
        collectionView.reloadData()
    }
       
    override func reloadDataSourceNetwork() {
           
        if isSearching {
            networkSearch()
            return
        }
                    
        if serverUrl != "" {
           
            isReloadDataSourceNetworkInProgress = true
            collectionView?.reloadData()
            
            NCNetworking.shared.readFolder(serverUrl: serverUrl, account: appDelegate.account) { (account, metadataFolder, metadatas, metadatasUpdate, metadatasLocalUpdate, errorCode, errorDescription) in
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
                self.isReloadDataSourceNetworkInProgress = false
                self.reloadDataSource()
            }
        }
    }
}
