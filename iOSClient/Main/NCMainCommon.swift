//
//  NCMainCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/07/18.
//  Copyright © 2018 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class NCMainCommon {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc func cellForRowAtIndexPath(_ indexPath: IndexPath, tableView: UITableView ,metadata: tableMetadata, serverUrl: String, autoUploadFileName: String, autoUploadDirectory: String, fatherPermission: String, e2e2: Bool) -> UITableViewCell {
        
        if metadata.directory {
            CCUtility.getDirectoryProviderStorageFileID(metadata.fileID)
        } else {
            CCUtility.getDirectoryProviderStorageFileID(metadata.fileID, fileName: metadata.fileNameView)
        }
        
        // CCCell
        if metadata.status == k_metadataStatusNormal {
            
            // NORMAL
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "CellMain", for: indexPath) as! CCCellMain
            cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0)
            cell.accessoryType = UITableViewCellAccessoryType.none
            cell.file.image = nil
            cell.status.image = nil
            cell.favorite.image = nil
            cell.shared.image = nil
            cell.local.image = nil
            cell.imageTitleSegue = nil
            
            cell.backgroundColor = NCBrandColor.sharedInstance.backgroundView
            
            // change color selection
            let selectionColor = UIView()
            selectionColor.backgroundColor = NCBrandColor.sharedInstance.getColorSelectBackgrond()
            cell.selectedBackgroundView = selectionColor
            cell.tintColor = NCBrandColor.sharedInstance.brandElement
            
            cell.labelTitle.textColor = UIColor.black
            cell.labelTitle.text = metadata.fileNameView;
            
            let shareLink = appDelegate.sharesLink.object(forKey: serverUrl+metadata.fileName)
            let shareUserAndGroup = appDelegate.sharesUserAndGroup.object(forKey: serverUrl+metadata.fileName)
            let isShare = metadata.permissions.contains(k_permission_shared) && !fatherPermission.contains(k_permission_shared)
            let isMounted = metadata.permissions.contains(k_permission_mounted) && !fatherPermission.contains(k_permission_mounted)

            if metadata.directory {
                
                // lable Info
                cell.labelInfoFile.text = CCUtility.dateDiff(metadata.date as Date)
                
                // File Image & Image Title Segue
                if metadata.e2eEncrypted {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderEncrypted"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "lock")
                } else if metadata.fileName == autoUploadFileName && serverUrl == autoUploadDirectory {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderPhotos"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "photos")
                } else if isShare {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_shared_with_me"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "share")
                } else if isMounted {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_external"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "shareMounted")
                } else if (shareUserAndGroup != nil) {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_shared_with_me"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "share")
                } else if (shareLink != nil) {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_public"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "sharebylink")
                } else {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                }
                
                // Image Status Lock Passcode
                let lockServerUrl = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)!
                let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.activeAccount, lockServerUrl))
                if tableDirectory != nil && tableDirectory!.lock && CCUtility.getBlockCode() != nil {
                    cell.status.image = UIImage.init(named: "passcode")
                }
                
            } else {
                
                let iconFileExists = FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileNameView))
                
                // Lable Info
                cell.labelInfoFile.text = CCUtility.dateDiff(metadata.date as Date) + " " + CCUtility.transformedSize(metadata.size)
                
                // File Image
                if iconFileExists {
                    cell.file.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileNameView))
                } else {
                    if metadata.iconName.count > 0 {
                        cell.file.image = UIImage.init(named: metadata.iconName)
                    } else {
                        cell.file.image = UIImage.init(named: "file")
                    }
                }
                
                // Local Image
                let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
                if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.fileID, fileName: metadata.fileNameView) {
                    cell.local.image = UIImage.init(named: "local")
                }
                
                // Status Image
                let tableE2eEncryption = NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNameIdentifier == %@", appDelegate.activeAccount, metadata.fileName))
                if tableE2eEncryption != nil &&  NCUtility.sharedInstance.isEncryptedMetadata(metadata) {
                    cell.status.image = UIImage.init(named: "encrypted")
                }
                
                // Share
                if (isShare) {
                    cell.shared.image =  CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
                } else if (isMounted) {
                    cell.shared.image =  CCGraphics.changeThemingColorImage(UIImage.init(named: "shareMounted"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
                } else if (shareLink != nil) {
                    cell.shared.image =  CCGraphics.changeThemingColorImage(UIImage.init(named: "sharebylink"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
                } else if (shareUserAndGroup != nil) {
                    cell.shared.image =  CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
                }
            }
            
            //
            // File & Directory
            //
            
            // Favorite
            if metadata.favorite {
                cell.favorite.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
            }
            
            return cell
        } else {
         
            // TRASNFER
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "CellMainTransfer", for: indexPath) as! CCCellMainTransfer
            cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0)
            cell.accessoryType = UITableViewCellAccessoryType.none
            cell.file.image = nil;
            cell.status.image = nil;
            
            cell.backgroundColor = NCBrandColor.sharedInstance.backgroundView

            cell.labelTitle.textColor = UIColor.black
            cell.labelTitle.text = metadata.fileNameView;
            
            cell.transferButton.tintColor = NCBrandColor.sharedInstance.icon
            
            var progress: CGFloat = 0.0
            var totalBytes: Double = 0
            var totalBytesExpected : Double = 0
            let progressArray = appDelegate.listProgressMetadata.object(forKey: metadata.fileID) as? NSArray
            if progressArray != nil && progressArray?.count == 3 {
                progress = progressArray?.object(at: 0) as! CGFloat
                totalBytes = progressArray?.object(at: 1) as! Double
                totalBytesExpected = progressArray?.object(at: 2) as! Double
            }
            
            // Write status on Label Info
            switch metadata.status {
            case 2:
                cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size) + " " + NSLocalizedString("_status_wait_download_", comment: "")
                break
            case 3:
                cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size) + " " + NSLocalizedString("_status_in_download_", comment: "")
                break
            case 4:
                if totalBytes > 0 {
                    cell.labelInfoFile.text = CCUtility.transformedSize(totalBytesExpected) + " - ↓" + CCUtility.transformedSize(totalBytes)
                } else {
                    cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size)
                }
                break
            case 6:
                cell.labelInfoFile.text = NSLocalizedString("_status_wait_upload_", comment: "")
                break
            case 7:
                cell.labelInfoFile.text = NSLocalizedString("_status_in_upload_", comment: "")
                break
            case 8:
                if totalBytes > 0 {
                    cell.labelInfoFile.text = CCUtility.transformedSize(totalBytesExpected) + " - ↑" + CCUtility.transformedSize(totalBytes)
                } else {
                    cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size)
                }
                break
            default:
                cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size)
            }
            
            let iconFileExists = FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileNameView))

            if iconFileExists {
                cell.file.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileNameView))
            } else {
                if metadata.iconName.count > 0 {
                    cell.file.image = UIImage.init(named: metadata.iconName)
                } else {
                    cell.file.image = UIImage.init(named: "file")
                }
            }
            
            // Session Upload Extension
            if metadata.session == k_upload_session_extension && (metadata.status == k_metadataStatusInUpload || metadata.status == k_metadataStatusUploading) {
                
                cell.labelTitle.isEnabled = false
                cell.labelInfoFile.isEnabled = false
                
            } else {
                
                cell.labelTitle.isEnabled = true
                cell.labelInfoFile.isEnabled = true
            }
            
            // downloadFile
            if metadata.status == k_metadataStatusWaitDownload || metadata.status == k_metadataStatusInDownload || metadata.status == k_metadataStatusDownloading || metadata.status == k_metadataStatusDownloadError {
                //
            }
            
            // downloadFile Error
            if metadata.status == k_metadataStatusDownloadError {
                
                cell.status.image = UIImage.init(named: "statuserror")
                
                if metadata.sessionError.count == 0 {
                    cell.labelInfoFile.text = NSLocalizedString("_error_", comment: "") + ", " + NSLocalizedString("_file_not_downloaded_", comment: "")
                } else {
                    cell.labelInfoFile.text = metadata.sessionError
                }
            }
            
            // uploadFile
            if metadata.status == k_metadataStatusWaitUpload || metadata.status == k_metadataStatusInUpload || metadata.status == k_metadataStatusUploading || metadata.status == k_metadataStatusUploadError {
                
                if (!iconFileExists) {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "uploadCloud"), multiplier: 2, color: NCBrandColor.sharedInstance.brandElement)
                }
                
                cell.labelTitle.isEnabled = false
            }
            
            // uploadFileError
            if metadata.status == k_metadataStatusUploadError {
                
                cell.labelTitle.isEnabled = false
                cell.status.image = UIImage.init(named: "statuserror")
                
                if !iconFileExists {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "uploadCloud"), multiplier: 2, color: NCBrandColor.sharedInstance.brandElement)
                }
                
                if metadata.sessionError.count == 0 {
                    cell.labelInfoFile.text = NSLocalizedString("_error_", comment: "") + ", " + NSLocalizedString("_file_not_uploaded_", comment: "")
                } else {
                    cell.labelInfoFile.text = metadata.sessionError
                }
            }
            
            // Progress
            cell.transferButton.progress = progress
            
            return cell
        }
    }
    
}

