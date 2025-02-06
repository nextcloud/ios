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

class NCTransfers: NCCollectionViewCommon, NCTransferCellDelegate {
    var metadataTemp: tableMetadata?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_transfers_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewTransfers
        enableSearchBar = false
        headerRichWorkspaceDisable = true
        emptyImageName = "arrow.left.arrow.right.circle"
        emptyTitle = "_no_transfer_"
        emptyDescription = "_no_transfer_sub_"
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        listLayout.itemHeight = 105
        self.database.setLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl, layout: NCGlobal.shared.layoutList)
        self.navigationItem.title = titleCurrentFolder
        navigationController?.navigationBar.tintColor = NCBrandColor.shared.iconImageColor

        let close = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .done) {
            self.dismiss(animated: true)
        }

        self.navigationItem.leftBarButtonItems = [close]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reloadDataSource()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: global.notificationCenterProgressTask), object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: global.notificationCenterProgressTask), object: nil)
    }

    // MARK: - NotificationCenter

    override func reloadDataSource(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func deleteFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func copyMoveFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func renameFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func createFolder(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func favoriteFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func downloadStartFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func downloadedFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func downloadCancelFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func uploadStartFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func uploadedFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func uploadedLivePhoto(_ notification: NSNotification) {
        reloadDataSource()
    }

    override func uploadCancelFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    @objc func triggerProgressTask(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let progressNumber = userInfo["progress"] as? NSNumber,
              let totalBytes = userInfo["totalBytes"] as? Int64,
              let totalBytesExpected = userInfo["totalBytesExpected"] as? Int64,
              let ocId = userInfo["ocId"] as? String,
              let ocIdTransfer = userInfo["ocIdTransfer"] as? String,
              let session = userInfo["session"] as? String
        else { return }
        let chunk: Int = userInfo["chunk"] as? Int ?? 0
        let e2eEncrypted: Bool = userInfo["e2eEncrypted"] as? Bool ?? false
        NCTransferProgress.shared.append(NCTransferProgress.Transfer(ocId: ocId, ocIdTransfer: ocIdTransfer, session: session, chunk: chunk, e2eEncrypted: e2eEncrypted, progressNumber: progressNumber, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected))

        DispatchQueue.main.async {
            for case let cell as NCTransferCell in self.collectionView.visibleCells {
                if cell.fileOcIdTransfer == ocIdTransfer {
                    cell.setProgress(progress: progressNumber.floatValue)
                    cell.fileInfoLabel?.text = self.utilityFileSystem.transformedSize(totalBytesExpected) + " - " + self.utilityFileSystem.transformedSize(totalBytes)
                }
            }
        }
    }

    // MARK: TAP EVENT

    override func tapMoreGridItem(with ocId: String, ocIdTransfer: String, image: UIImage?, sender: Any) {
        guard let metadata = self.database.getMetadataFromOcIdAndocIdTransfer(ocIdTransfer) else { return }
        NCNetworking.shared.cancelTask(metadata: metadata)
    }

    override func longPressMoreListItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer) {
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

    override func longPressListItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state != .began { return }

        if let metadata = self.database.getMetadataFromOcIdAndocIdTransfer(ocIdTransfer) {
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
        guard let metadata = metadataTemp else { return }
        let cameraRoll = NCCameraRoll()

        cameraRoll.extractCameraRoll(from: metadata) { metadatas in
            for metadata in metadatas {
                if let metadata = self.database.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusUploading) {
                    NCTransferProgress.shared.clearCountError(ocIdTransfer: metadata.ocIdTransfer)
                    NCNetworking.shared.upload(metadata: metadata)
                }
            }
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action != #selector(startTask(_:)) { return false }
        guard let metadata = metadataTemp else { return false }
        if metadata.isDirectoryE2EE { return false }

        if metadata.isUpload {
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
        let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "transferCell", for: indexPath) as? NCTransferCell)!
        guard let metadata = self.dataSource.getResultMetadata(indexPath: indexPath) else {
            return cell
        }
        let transfer = NCTransferProgress.shared.get(ocId: metadata.ocId, ocIdTransfer: metadata.ocIdTransfer, session: metadata.session)

        cell.delegate = self
        cell.fileOcId = metadata.ocId
        cell.fileOcIdTransfer = metadata.ocIdTransfer
        cell.fileUser = metadata.ownerId
        cell.filePreviewImageView?.image = imageCache.getImageFile()
        cell.filePreviewImageView?.backgroundColor = nil
        cell.labelTitle.text = metadata.fileNameView
        cell.labelTitle.textColor = NCBrandColor.shared.textColor
        let serverUrlHome = utilityFileSystem.getHomeServer(session: session)
        var pathText = metadata.serverUrl.replacingOccurrences(of: serverUrlHome, with: "")
        if pathText.isEmpty { pathText = "/" }
        cell.labelPath.text = pathText
        cell.setButtonMore(image: imageCache.getImageButtonStop())

        /// Image item
        if !metadata.iconName.isEmpty {
            cell.filePreviewImageView?.image = utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
        } else {
            cell.filePreviewImageView?.image = imageCache.getImageFile()
        }

        /// Status and Info
        let user = (metadata.user == session.user ? "" : " - " + metadata.account)
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitCreateFolder:
            cell.fileStatusImage?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_create_folder_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitDelete:
            cell.fileStatusImage?.image = utility.loadImage(named: "trash.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_delete_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitFavorite:
            cell.fileStatusImage?.image = utility.loadImage(named: "star.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_favorite_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitCopy:
            cell.fileStatusImage?.image = utility.loadImage(named: "c.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_copy_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitMove:
            cell.fileStatusImage?.image = utility.loadImage(named: "m.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_move_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitRename:
            cell.fileStatusImage?.image = utility.loadImage(named: "a.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_rename_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.fileStatusImage?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_download_", comment: "") + user
            cell.labelInfo.text = utilityFileSystem.transformedSize(metadata.size)
        case NCGlobal.shared.metadataStatusDownloading:
            if #available(iOS 17.0, *) {
                cell.fileStatusImage?.image = utility.loadImage(named: "arrowshape.down.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            }
            cell.labelStatus.text = NSLocalizedString("_status_downloading_", comment: "") + user
            cell.labelInfo.text = utilityFileSystem.transformedSize(metadata.size) + " - " + self.utilityFileSystem.transformedSize(transfer.totalBytes)
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.fileStatusImage?.image = utility.loadImage(named: "arrow.triangle.2.circlepath", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_wait_upload_", comment: "") + user
            cell.labelInfo.text = ""
        case NCGlobal.shared.metadataStatusUploading:
            if #available(iOS 17.0, *) {
                cell.fileStatusImage?.image = utility.loadImage(named: "arrowshape.up.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            }
            cell.labelStatus.text = NSLocalizedString("_status_uploading_", comment: "") + user
            cell.labelInfo.text = utilityFileSystem.transformedSize(metadata.size) + " - " + self.utilityFileSystem.transformedSize(transfer.totalBytes)
        case NCGlobal.shared.metadataStatusDownloadError, NCGlobal.shared.metadataStatusUploadError:
            cell.fileStatusImage?.image = utility.loadImage(named: "exclamationmark.circle", colors: NCBrandColor.shared.iconImageMultiColors)
            cell.labelStatus.text = NSLocalizedString("_status_upload_error_", comment: "") + user
            cell.labelInfo.text = metadata.sessionError
        default:
            cell.fileStatusImage?.image = nil
            cell.labelStatus.text = ""
            cell.labelInfo.text = ""
        }

        if metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan && !(NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi) {
            cell.labelInfo.text = NSLocalizedString("_waiting_for_", comment: "") + " " + NSLocalizedString("_reachable_wifi_", comment: "")
        }
        cell.accessibilityLabel = metadata.fileNameView + ", " + (cell.labelInfo.text ?? "")

        /// Progress view
        if let transfer = NCTransferProgress.shared.get(ocIdTransfer: metadata.ocIdTransfer) {
            cell.setProgress(progress: transfer.progressNumber.floatValue)
        } else {
            cell.setProgress(progress: 0.0)
        }

        /// Remove last separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 {
            cell.separator.isHidden = true
        } else {
            cell.separator.isHidden = false
        }

        return cell
    }

    // MARK: - DataSource

    override func reloadDataSource() {
        let directoryOnTop = NCKeychain().getDirectoryOnTop(account: session.account)

        if let results = self.database.getResultsMetadatas(predicate: NSPredicate(format: "status != %i", NCGlobal.shared.metadataStatusNormal), sortedByKeyPath: "sessionDate", ascending: true) {
            self.dataSource = NCCollectionViewDataSource(metadatas: Array(results.freeze()), layoutForView: layoutForView, directoryOnTop: directoryOnTop)
        } else {
            self.dataSource.removeAll()
        }

        if self.dataSource.isEmpty() {
            NCTransferProgress.shared.removeAll()
        }

        super.reloadDataSource()
    }

    override func getServerData() {
        reloadDataSource()
    }
}
