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

class NCFavorite: NCCollectionViewCommon  {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        appDelegate.activeFavorite = self
        titleCurrentFolder = NSLocalizedString("_favorites_", comment: "")
        layoutKey = k_layout_view_favorite
    }
    
    // MARK: DZNEmpty
        
    override func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 300, height: 300, color: NCBrandColor.sharedInstance.yellowFavorite)
    }
    
    override func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_favorite_no_files_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    override func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let text = "\n"+NSLocalizedString("_tutorial_favorite_view_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }

    override func tapMoreGridItem(with objectId: String, namedButtonMore: String, sender: Any) {
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", objectId)) else { return }
        guard let tabBarController = self.tabBarController else { return }

        if namedButtonMore == "more" {
            toggleMoreMenu(viewController: tabBarController, metadata: metadata)
        } else if namedButtonMore == "stop" {
            NCMainCommon.shared.cancelTransferMetadata(metadata, uploadStatusForcedStart: false)
        }
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
            let ncFavorite:NCFavorite = UIStoryboard(name: "NCFavorite", bundle: nil).instantiateInitialViewController() as! NCFavorite
            
            ncFavorite.serverUrl = serverUrlPush
            ncFavorite.titleCurrentFolder = metadataPush!.fileNameView
            
            self.navigationController?.pushViewController(ncFavorite, animated: true)
            
        } else {
            
            if CCUtility.fileProviderStorageExists(metadataPush?.ocId, fileNameView: metadataPush?.fileNameView) {
                performSegue(withIdentifier: "segueDetail", sender: self)
            } else {
                NCNetworking.shared.download(metadata: metadataPush!, selector: selectorLoadFileViewFavorite) { (_) in }
            }
        }
    }
    
    // MARK: - NC API & Algorithm
    
    override func reloadDataSource() {
        
        var sort: String
        var ascending: Bool
        var directoryOnTop: Bool
        
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey)
        
        if serverUrl == "" {
            
            let metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND favorite == true", appDelegate.account))
            self.dataSource = NCDataSource.init(metadatasSource: metadatasSource, sort: sort, ascending: ascending, directoryOnTop: directoryOnTop, filterLivePhoto: true)
            
        } else {
            
            let metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
            self.dataSource = NCDataSource.init(metadatasSource: metadatasSource, sort: sort, ascending: ascending, directoryOnTop: directoryOnTop, filterLivePhoto: true)
        }
        
        refreshControl.endRefreshing()
        collectionView.reloadData()
    }
    
    override func reloadDataSourceNetwork() {
     
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
                }
                self.reloadDataSource()
            }
            
        } else {
            
            NCNetworking.shared.readFolder(serverUrl: serverUrl, account: appDelegate.account) { (account, metadataFolder, metadatas, metadatasUpdate, metadatasLocalUpdate, errorCode, errorDescription) in
                if errorCode == 0 {
                    for metadata in metadatas ?? [] {
                        if !metadata.directory && CCUtility.getFavoriteOffline() {
                            let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                            if localFile == nil || localFile?.etag != metadata.etag {
                                NCOperationQueue.shared.download(metadata: metadata, selector: selectorDownloadFile, setFavorite: false)
                            }
                        }
                    }
                }
                self.reloadDataSource()
            }
        }
    }
}

