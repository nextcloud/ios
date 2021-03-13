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

class NCTransfers: NCCollectionViewCommon, NCTransferCellDelegate  {
    
    var metadataTemp: tableMetadata?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        titleCurrentFolder = NSLocalizedString("_transfers_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewTransfers
        enableSearchBar = false
        emptyImage = UIImage.init(named: "arrow.left.arrow.right")?.image(color: .gray, size: UIScreen.main.bounds.width)
        emptyTitle = "_no_transfer_"
        emptyDescription = "_no_transfer_sub_"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        listLayout.itemHeight = 105
    }
    
    override func viewWillAppear(_ animated: Bool) {

        appDelegate.activeViewController = self
        
        collectionView?.collectionViewLayout = listLayout
        
        self.navigationItem.title = titleCurrentFolder
        
        setNavigationItem()
        
        reloadDataSource()
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
        reloadDataSource()
    }
    
    override func uploadedFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        reloadDataSource()
    }
    
    override func uploadCancelFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        reloadDataSource()
    }
    
    // MARK: TAP EVENT
    
    override func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {
        
        if gestureRecognizer.state != .began { return }
        
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
        
        if gestureRecognizer.state != .began { return }
        
        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) {
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
            
        metadata.status = NCGlobal.shared.metadataStatusInUpload
        metadata.session = NCCommunicationCommon.shared.sessionIdentifierUpload
        
        NCManageDatabase.shared.addMetadata(metadata)
        NCNetworking.shared.upload(metadata: metadata) { (_, _) in }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        
        if action != #selector(startTask(_:)) { return false }
        guard let metadata = metadataTemp else { return false }
        if metadata.e2eEncrypted { return false }
        
        if metadata.status == NCGlobal.shared.metadataStatusWaitUpload || metadata.status == NCGlobal.shared.metadataStatusInUpload || metadata.status == NCGlobal.shared.metadataStatusUploading {
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
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
       
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "transferCell", for: indexPath) as! NCTransferCell
        }
                
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "transferCell", for: indexPath) as! NCTransferCell
        cell.delegate = self
            
        cell.objectId = metadata.ocId
        cell.indexPath = indexPath
        
        cell.imageItem.image = nil
        cell.imageItem.backgroundColor = nil
        
        cell.labelTitle.text = metadata.fileNameView
        cell.labelTitle.textColor = NCBrandColor.shared.textView
        
        let serverUrlHome = NCUtilityFileSystem.shared.getHomeServer(urlBase: metadata.urlBase, account: metadata.account)
        var pathText = metadata.serverUrl.replacingOccurrences(of: serverUrlHome, with: "")
        if pathText == "" { pathText = "/" }
        cell.labelPath.text = pathText
        
        cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCCollectionCommon.images.buttonStop)

        cell.progressView.progress = 0.0
        cell.separator.backgroundColor = NCBrandColor.shared.separator
                
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            cell.imageItem.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
        } else if metadata.typeFile == NCGlobal.shared.metadataTypeFileImage && FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)) {
            cell.imageItem.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
        }
        
        if cell.imageItem.image == nil {
            cell.imageItem.image = NCCollectionCommon.images.file
        }
        
        cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date) + " · " + CCUtility.transformedSize(metadata.size)
        
        // Transfer
        var progress: Float = 0.0
        var totalBytes: Int64 = 0
        if let progressType = appDelegate.listProgress[metadata.ocId] {
            progress = progressType.progress
            totalBytes = progressType.totalBytes
        }
        
        if metadata.status == NCGlobal.shared.metadataStatusInDownload || metadata.status == NCGlobal.shared.metadataStatusDownloading ||  metadata.status >= NCGlobal.shared.metadataStatusTypeUpload {
            cell.progressView.isHidden = false
        } else {
            cell.progressView.isHidden = true
            cell.progressView.progress = progress
        }

        // Write status on Label Info
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.labelStatus.text = NSLocalizedString("_status_wait_download_", comment: "")
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size)
            break
        case NCGlobal.shared.metadataStatusInDownload:
            cell.labelStatus.text = NSLocalizedString("_status_in_download_", comment: "")
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size)
            break
        case NCGlobal.shared.metadataStatusDownloading:
            cell.labelStatus.text = NSLocalizedString("_status_downloading_", comment: "")
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - ↓ " + CCUtility.transformedSize(totalBytes)
            break
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.labelStatus.text = NSLocalizedString("_status_wait_upload_", comment: "")
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size)
            break
        case NCGlobal.shared.metadataStatusInUpload:
            cell.labelStatus.text = NSLocalizedString("_status_in_upload_", comment: "")
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size)
            break
        case NCGlobal.shared.metadataStatusUploading:
            cell.labelStatus.text = NSLocalizedString("_status_uploading_", comment: "")
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - ↑ " + CCUtility.transformedSize(totalBytes)
            break
        default:
            cell.labelStatus.text = ""
            cell.labelInfo.text = ""
            break
        }
                        
        // Remove last separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 {
            cell.separator.isHidden = true
        } else {
            cell.separator.isHidden = false
        }
        
        return cell
    }
    
    // MARK: - DataSource + NC Endpoint

    override func reloadDataSource() {
        super.reloadDataSource()
                
        metadatasSource = NCManageDatabase.shared.getAdvancedMetadatas(predicate: NSPredicate(format: "(session CONTAINS 'upload') OR (session CONTAINS 'download')"), page: 1, limit: 100, sorted: "sessionTaskIdentifier", ascending: false)
        self.dataSource = NCDataSource.init(metadatasSource: metadatasSource)
        
        refreshControl.endRefreshing()
        collectionView.reloadData()
    }
    
    override func reloadDataSourceNetwork(forced: Bool = false) {
        super.reloadDataSourceNetwork(forced: forced)
        
        reloadDataSource()
    }
}
