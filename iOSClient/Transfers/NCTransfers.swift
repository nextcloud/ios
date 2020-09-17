//
//  NCTransfers.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/09/2020.
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

class NCTransfers: NCCollectionViewCommon  {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        appDelegate.activeTransfers = self
        titleCurrentFolder = NSLocalizedString("_transfers_", comment: "")
        layoutKey = k_layout_view_transfers
        enableSearchBar = false
        DZNimage = CCGraphics.changeThemingColorImage(UIImage.init(named: "load"), width: 300, height: 300, color: NCBrandColor.sharedInstance.brandElement)
        DZNtitle = "_no_transfer_"
        DZNdescription = "_no_transfer_sub_"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    // MARK: - NotificationCenter
    
    override func downloadStartFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        reloadDataSource()
    }
    
    override func downloadedFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        reloadDataSource()
    }
    
    override func downloadCancelFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        reloadDataSource()
    }
    
    override func uploadStartFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {

                if let row = dataSource?.addMetadata(metadata) {
                    let indexPath = IndexPath(row: row, section: 0)
                    collectionView?.performBatchUpdates({
                        collectionView?.insertItems(at: [indexPath])
                    }, completion: { (_) in
                        self.collectionView?.reloadData()
                    })
                }
            }
        }
    }
    
    override func uploadedFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let ocIdTemp = userInfo["ocIdTemp"] as? String, let errorCode = userInfo["errorCode"] as? Int {
                if errorCode == 0 {
                    
                    if let row = dataSource?.deleteMetadata(ocId: metadata.ocId) {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.performBatchUpdates({
                            collectionView?.deleteItems(at: [indexPath])
                        }, completion: { (_) in
                            self.collectionView?.reloadData()
                        })
                    } else {
                        reloadDataSource()
                    }
                    
                } else if errorCode != NSURLErrorCancelled {
                    
                    if let row = dataSource?.reloadMetadata(ocId: metadata.ocId, ocIdTemp: ocIdTemp) {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.performBatchUpdates({
                            collectionView?.reloadItems(at: [indexPath])
                        }, completion: { (_) in
                            self.collectionView?.reloadData()
                        })
                    } else {
                        reloadDataSource()
                    }
                }
            }
        }
    }
    
    override func uploadCancelFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                    
                if let row = dataSource?.deleteMetadata(ocId: metadata.ocId) {
                    let indexPath = IndexPath(row: row, section: 0)
                    collectionView?.performBatchUpdates({
                        collectionView?.deleteItems(at: [indexPath])
                    }, completion: { (_) in
                        self.collectionView?.reloadData()
                    })
                } else {
                    self.reloadDataSource()
                }
            }
        }
    }
    
    // MARK: - Collection View
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        super.collectionView(collectionView, didSelectItemAt: indexPath)
    }
    
    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 0)
    }
    
    // MARK: - NC API & Algorithm

    override func reloadDataSource() {
        super.reloadDataSource()
        
        var sort: String
        var ascending: Bool
        var directoryOnTop: Bool
        
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey)
        
        metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "(session CONTAINS 'upload') OR (session CONTAINS 'download')"), page: 1, limit: 100, sorted: "sessionTaskIdentifier", ascending: false)
        self.dataSource = NCDataSource.init(metadatasSource: metadatasSource, sort: sort, ascending: ascending, directoryOnTop: directoryOnTop, filterLivePhoto: false)
        
        refreshControl.endRefreshing()
        collectionView.reloadData()
    }
    
    override func reloadDataSourceNetwork() {
        super.reloadDataSourceNetwork()
        
        reloadDataSource()
    }
}
