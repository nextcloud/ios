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

import UIKit
import NextcloudKit
import JGProgressHUD

class NCTransfers: NCCollectionViewCommon, NCTransferCellDelegate {

    var metadataTemp: tableMetadata?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_transfers_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewTransfers
        enableSearchBar = false
        headerRichWorkspaceDisable = true
        headerMenuTransferView = true
        emptyImage = utility.loadImage(named: "arrow.left.arrow.right", colors: [NCBrandColor.shared.brandElement])
        emptyTitle = "_no_transfer_"
        emptyDescription = "_no_transfer_sub_"
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        listLayout.itemHeight = 105
        NCManageDatabase.shared.setLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl, layout: NCGlobal.shared.layoutList)
        self.navigationItem.title = titleCurrentFolder
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadDataSource()
        Task {
            await NCNetworkingProcess.shared.verifyZombie()
        }
    }

    override func setNavigationLeftItems() {
        self.navigationItem.rightBarButtonItem = nil
        self.navigationItem.leftBarButtonItem = nil
    }

    // MARK: - NotificationCenter

    override func downloadStartFile(_ notification: NSNotification) {

        notificationReloadDataSource += 1
    }

    override func downloadedFile(_ notification: NSNotification) {

        notificationReloadDataSource += 1
    }

    override func downloadCancelFile(_ notification: NSNotification) {

        reloadDataSource()
    }

    override func uploadStartFile(_ notification: NSNotification) {

        notificationReloadDataSource += 1
    }

    override func uploadedFile(_ notification: NSNotification) {

        notificationReloadDataSource += 1
    }

    override func uploadedLivePhoto(_ notification: NSNotification) {

        notificationReloadDataSource += 1
    }

    override func uploadCancelFile(_ notification: NSNotification) {

        reloadDataSource()
    }

    // MARK: TAP EVENT

    override func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any) {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }

        Task {
            await cancelSession(metadata: metadata)
        }
    }

    override func longPressMoreListItem(with objectId: String, namedButtonMore: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) {

        if gestureRecognizer.state != .began { return }
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_all_task_", comment: ""), style: .default, handler: { _ in
            NCNetworking.shared.cancelAllTask()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.reloadDataSource()
            }
        }))

        self.present(alertController, animated: true, completion: nil)
    }

    override func longPressListItem(with objectId: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) {

        if gestureRecognizer.state != .began { return }

        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) {
            metadataTemp = metadata
            let touchPoint = gestureRecognizer.location(in: collectionView)
            becomeFirstResponder()
            let startTaskItem = UIMenuItem(title: NSLocalizedString("_force_start_", comment: ""), action: #selector(startTask(_:)))
            UIMenuController.shared.menuItems = [startTaskItem]
            UIMenuController.shared.showMenu(from: collectionView, rect: CGRect(x: touchPoint.x, y: touchPoint.y, width: 0, height: 0))
        }
    }

    override func longPressCollecationView(_ gestureRecognizer: UILongPressGestureRecognizer) { }

    @objc func startTask(_ notification: Any) {

        guard let metadata = metadataTemp,
              let hudView = self.tabBarController?.view,
              appDelegate.account == metadata.account else { return }

        let cameraRoll = NCCameraRoll()
        cameraRoll.extractCameraRoll(from: metadata) { metadatas in
            for metadata in metadatas {
                if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusUploading) {
                    NCNetworking.shared.removeTransferInError(ocId: metadata.ocId)
                    NCNetworking.shared.upload(metadata: metadata, hudView: hudView, hud: JGProgressHUD())
                }
            }
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        if action != #selector(startTask(_:)) { return false }
        guard let metadata = metadataTemp else { return false }
        if metadata.isDirectoryE2EE { return false }

        if metadata.status == NCGlobal.shared.metadataStatusWaitUpload || metadata.isUpload {
            return true
        }

        return false
    }

    // MARK: - Collection View

    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return nil
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // nothing
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "transferCell", for: indexPath) as? NCTransferCell,
              let metadata = dataSource.cellForItemAt(indexPath: indexPath) else {
            return NCTransferCell()
        }

        cell.delegate = self

        cell.fileObjectId = metadata.ocId
        cell.indexPath = indexPath
        cell.fileUser = metadata.ownerId
        cell.indexPath = indexPath
        cell.imageItem.image = NCImageCache.images.file
        cell.imageItem.backgroundColor = nil
        cell.labelTitle.text = metadata.fileNameView
        cell.labelTitle.textColor = NCBrandColor.shared.textColor
        let serverUrlHome = utilityFileSystem.getHomeServer(urlBase: metadata.urlBase, userId: metadata.userId)
        var pathText = metadata.serverUrl.replacingOccurrences(of: serverUrlHome, with: "")
        if pathText.isEmpty { pathText = "/" }
        cell.labelPath.text = pathText
        cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCImageCache.images.buttonStop)
        cell.progressView.progress = 0.0
        if let image = utility.getIcon(metadata: metadata) {
            cell.imageItem.image = image
        } else if !metadata.iconName.isEmpty {
            cell.imageItem.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true)
        } else {
            cell.imageItem.image = NCImageCache.images.file
        }
        cell.labelInfo.text = utility.dateDiff(metadata.date as Date) + " · " + utilityFileSystem.transformedSize(metadata.size)
        if metadata.status == NCGlobal.shared.metadataStatusDownloading || metadata.status == NCGlobal.shared.metadataStatusUploading {
            cell.progressView.isHidden = false
        } else {
            cell.progressView.isHidden = true
        }
        // Write status on Label Info
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.labelStatus.text = NSLocalizedString("_status_wait_download_", comment: "")
            cell.labelInfo.text = utilityFileSystem.transformedSize(metadata.size)
        case NCGlobal.shared.metadataStatusDownloading:
            cell.labelStatus.text = NSLocalizedString("_status_downloading_", comment: "")
            cell.labelInfo.text = utilityFileSystem.transformedSize(metadata.size) + " - ↓ …"
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.labelStatus.text = NSLocalizedString("_status_wait_upload_", comment: "")
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusUploading:
            cell.labelStatus.text = NSLocalizedString("_status_uploading_", comment: "")
            cell.labelInfo.text = utilityFileSystem.transformedSize(metadata.size) + " - ↑ …"
        case NCGlobal.shared.metadataStatusUploadError:
            cell.labelStatus.text = NSLocalizedString("_status_upload_error_", comment: "")
            cell.labelInfo.text = metadata.sessionError
        default:
            cell.labelStatus.text = ""
            cell.labelInfo.text = ""
        }
        if self.appDelegate.account != metadata.account {
            cell.labelInfo.text = NSLocalizedString("_waiting_for_", comment: "") + " " + NSLocalizedString("_user_", comment: "").lowercased() + " \(metadata.userId) " + NSLocalizedString("_in_", comment: "") + " \(metadata.urlBase)"
        }
        let isWiFi = NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi
        if metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan && !isWiFi {
            cell.labelInfo.text = NSLocalizedString("_waiting_for_", comment: "") + " " + NSLocalizedString("_reachable_wifi_", comment: "")
        }
        cell.accessibilityLabel = metadata.fileNameView + ", " + (cell.labelInfo.text ?? "")
        // Remove last separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 {
            cell.separator.isHidden = true
        } else {
            cell.separator.isHidden = false
        }

        return cell
    }

    // MARK: - DataSource + NC Endpoint

    override func queryDB() {
        super.queryDB()

        let metadatas: [tableMetadata] = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status != %i", NCGlobal.shared.metadataStatusNormal), sorted: "sessionDate", ascending: true) ?? []
        self.dataSource = NCDataSource(metadatas: metadatas, account: self.appDelegate.account, layoutForView: layoutForView)
    }

    override func reloadDataSource(withQueryDB: Bool = true) {
        super.reloadDataSource(withQueryDB: withQueryDB)
    }

    override func reloadDataSourceNetwork(withQueryDB: Bool = false) {
        Task {
            await NCNetworkingProcess.shared.verifyZombie()
            super.reloadDataSource(withQueryDB: true)
        }
    }
}
