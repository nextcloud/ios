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
    }
    
    // MARK: DZNEmpty
        
    override func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        
        if searchController?.isActive ?? false {
            return CCGraphics.changeThemingColorImage(UIImage.init(named: "search"), width: 300, height: 300, color: NCBrandColor.sharedInstance.yellowFavorite)
        }
        
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
    
    override func reloadDataSourceNetwork() {
       
        if isSearching {
        
            if literalSearch == nil || literalSearch?.count ?? 0 < 2 {
                self.reloadDataSource()
                return
            }
            
            NCNetworking.shared.searchFiles(urlBase: appDelegate.urlBase, user: appDelegate.user, literal: literalSearch!) { (account, metadatas, errorCode, errorDescription) in
                if self.searchController?.isActive ?? false && errorCode == 0 {
                    self.metadatasSource = metadatas!
                }
                self.reloadDataSource()
            }
            
        } else if serverUrl == "" {
            
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

