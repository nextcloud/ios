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
    
    var metadataTemp: tableMetadata?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        appDelegate.activeTransfers = self
        titleCurrentFolder = NSLocalizedString("_transfers_", comment: "")
        layoutKey = k_layout_view_transfers
        enableSearchBar = false
        DZNimage = CCGraphics.changeThemingColorImage(UIImage.init(named: "load"), width: 300, height: 300, color: .gray)
        DZNtitle = "_no_transfer_"
        DZNdescription = "_no_transfer_sub_"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func setNavigationItem() {
        self.navigationItem.rightBarButtonItem = nil
        self.navigationItem.leftBarButtonItem = nil
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
                        self.reloadDataSource()
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
    
    // MARK: TAP EVENT
    
    override func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
      
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
       
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_all_task_", comment: ""), style: .default, handler: { action in
            NCNetworking.shared.cancelAllTransfer(account: self.appDelegate.account) {
                self.reloadDataSource()
            }
        }))
       
        self.present(alertController, animated: true, completion: nil)
    }
    
    override func longPressListItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {
        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(objectId) {
            metadataTemp = metadata
            let touchPoint = gestureRecognizer.location(in: collectionView)
            becomeFirstResponder()
            let startTaskItem = UIMenuItem.init(title: NSLocalizedString("_force_start_", comment: ""), action: #selector(startTask(_:)))
            UIMenuController.shared.menuItems = [startTaskItem]
            UIMenuController.shared.setTargetRect(CGRect(x: touchPoint.x, y: touchPoint.y, width: 0, height: 0), in: collectionView)
            UIMenuController.shared.setMenuVisible(true, animated: true)
        }
    }
  
    override func longPressCollecationView(_ gestureRecognizer: UILongPressGestureRecognizer) { }
  
    @objc func startTask(_ notification: Any) {
        
        guard let metadata = metadataTemp else { return }
            
        metadata.status = Int(k_metadataStatusInUpload)
        metadata.session = NCCommunicationCommon.shared.sessionIdentifierUpload
        
        NCManageDatabase.sharedInstance.addMetadata(metadata)
        NCNetworking.shared.upload(metadata: metadata) { (_, _) in }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        
        if action != #selector(startTask(_:)) { return false }
        guard let metadata = metadataTemp else { return false }
        if metadata.e2eEncrypted { return false }
        
        if metadata.status == k_metadataStatusWaitUpload || metadata.status == k_metadataStatusInUpload || metadata.status == k_metadataStatusUploading {
            return true
        }
        
        return false
    }
    
    // MARK: - Collection View
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // nothing
    }
    
    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 0)
    }
    
    // MARK: - DataSource + NC Endpoint

    override func reloadDataSource() {
        super.reloadDataSource()
        
        (layout, _, _, groupBy, _, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey)
        
        metadatasSource = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "(session CONTAINS 'upload') OR (session CONTAINS 'download')"), page: 1, limit: 100, sorted: "sessionTaskIdentifier", ascending: false)
        self.dataSource = NCDataSource.init(metadatasSource: metadatasSource, sort: "sessionTaskIdentifier", ascending: true, directoryOnTop: false, filterLivePhoto: false)
        
        refreshControl.endRefreshing()
        collectionView.reloadData()
    }
    
    override func reloadDataSourceNetwork(forced: Bool = false) {
        super.reloadDataSourceNetwork(forced: forced)
        
        reloadDataSource()
    }
}
