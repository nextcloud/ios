//
//  NCActivityCollectionViewCell.swift
//  Nextcloud
//
//  Created by Henrik Storch on 17/01/2019.
//  Copyright © 2021. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

class NCActivityCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

class NCActivityTableViewCell: UITableViewCell, NCCellProtocol {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var subjectTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!

    private var user: String = ""

    var idActivity: Int = 0
    var account: String = ""
    var activityPreviews: [tableActivityPreview] = []
    var didSelectItemEnable: Bool = true
    var viewController: UIViewController? = nil
    
    var fileAvatarImageView: UIImageView? {
        get {
            return avatar
        }
    }
    var fileObjectId: String? {
        get {
            return nil
        }
    }
    var filePreviewImageView: UIImageView? {
        get {
            return nil
        }
    }
    var fileUser: String? {
        get {
            return user
        }
        set {
            user = newValue ?? ""
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        collectionView.delegate = self
        collectionView.dataSource = self
    }
}

// MARK: - Table View

extension NCActivity: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 60))
        view.backgroundColor = .clear
        
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.textColor = NCBrandColor.shared.label
        label.text = CCUtility.getTitleSectionDate(sectionDates[section])
        label.textAlignment = .center
        label.layer.cornerRadius = 11
        label.layer.masksToBounds = true
        label.layer.backgroundColor = UIColor(red: 152.0/255.0, green: 167.0/255.0, blue: 181.0/255.0, alpha: 0.8).cgColor
        let widthFrame = label.intrinsicContentSize.width + 30
        let xFrame = tableView.bounds.width / 2 - widthFrame / 2
        label.frame = CGRect(x: xFrame, y: 10, width: widthFrame, height: 22)
        
        view.addSubview(label)
        return view
    }
}

// MARK: - Collection View

extension NCActivityTableViewCell: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        // Select not permitted
        if !didSelectItemEnable {
            return
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionCell", for: indexPath) as? NCActivityCollectionViewCell
        
        let activityPreview = activityPreviews[indexPath.row]
        
        if activityPreview.view == "trashbin" {
            
            var responder: UIResponder? = collectionView
            while !(responder is UIViewController) {
                responder = responder?.next
                if nil == responder {
                    break
                }
            }
            if (responder as? UIViewController)!.navigationController != nil {
                if let viewController = UIStoryboard.init(name: "NCTrash", bundle: nil).instantiateInitialViewController() as? NCTrash {
                    if let result = NCManageDatabase.shared.getTrashItem(fileId: String(activityPreview.fileId), account: activityPreview.account) {
                        viewController.blinkFileId = result.fileId
                        viewController.trashPath = result.filePath
                        (responder as? UIViewController)!.navigationController?.pushViewController(viewController, animated: true)
                    } else {
                        NCContentPresenter.shared.messageNotification("_error_", description: "_trash_file_not_found_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorInternalError)
                    }
                }
            }
            
            return
        }
        
        if activityPreview.view == "files" && activityPreview.mimeType != "dir" {
            
            guard let activitySubjectRich = NCManageDatabase.shared.getActivitySubjectRich(account: activityPreview.account, idActivity: activityPreview.idActivity, id: String(activityPreview.fileId)) else {
                return
            }
            
            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "fileId == %@", activitySubjectRich.id)) {
                if let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView) {
                    do {
                        let attr = try FileManager.default.attributesOfItem(atPath: filePath)
                        let fileSize = attr[FileAttributeKey.size] as! UInt64
                        if fileSize > 0 {
                            if let viewController = self.viewController {
                                NCViewer.shared.view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: cell?.imageView.image)
                            }
                            return
                        }
                    } catch {
                        print("Error: \(error)")
                    }
                }
            }
            
            var pathComponents = activityPreview.link.components(separatedBy: "?")
            pathComponents = pathComponents[1].components(separatedBy: "&")
            var serverUrlFileName = pathComponents[0].replacingOccurrences(of: "dir=", with: "").removingPercentEncoding!
            serverUrlFileName = appDelegate.urlBase + "/" + NCUtilityFileSystem.shared.getWebDAV(account: activityPreview.account) + serverUrlFileName + "/" + activitySubjectRich.name
            
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(activitySubjectRich.id, fileNameView: activitySubjectRich.name)!
            
            NCUtility.shared.startActivityIndicator(backgroundView: (appDelegate.window?.rootViewController?.view)!, blurEffect: true)
            
            NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { (_) in
                
            }, taskHandler: { (_) in
                
            }, progressHandler: { (_) in
                
            }) { (account, etag, date, lenght, allHeaderFields, error, errorCode, errorDescription) in
                
                if account == self.appDelegate.account && errorCode == 0 {
                    
                    let serverUrl = (serverUrlFileName as NSString).deletingLastPathComponent
                    let fileName = (serverUrlFileName as NSString).lastPathComponent
                    let serverUrlFileName = serverUrl + "/" + fileName
                    
                    NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, account: activityPreview.account) { (account, metadata, errorCode, errorDescription) in
                        
                        NCUtility.shared.stopActivityIndicator()
                        
                        if account == self.appDelegate.account && errorCode == 0  {
                            
                            // move from id to oc:id + instanceid (ocId)
                            let atPath = CCUtility.getDirectoryProviderStorage()! + "/" + activitySubjectRich.id
                            let toPath = CCUtility.getDirectoryProviderStorage()! + "/" + metadata!.ocId
                                                       
                            CCUtility.moveFile(atPath: atPath, toPath: toPath)
                                                       
                            NCManageDatabase.shared.addMetadata(metadata!)
                            if let viewController = self.viewController {
                                NCViewer.shared.view(viewController: viewController, metadata: metadata!, metadatas: [metadata!], imageIcon: cell?.imageView.image)
                            }
                        }
                    }
                    
                } else {
                    
                    NCUtility.shared.stopActivityIndicator()
                }
            }
        }
    }
}

extension NCActivityTableViewCell: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return activityPreviews.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell: NCActivityCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionCell", for: indexPath) as! NCActivityCollectionViewCell
            
        cell.imageView.image = nil
        
        let activityPreview = activityPreviews[indexPath.row]
        let fileId = String(activityPreview.fileId)
        
        // Trashbin
        if activityPreview.view == "trashbin" {
            
            let source = activityPreview.source
            
            NCUtility.shared.convertSVGtoPNGWriteToUserData(svgUrlString: source, fileName: nil, width: 100, rewrite: false, account: appDelegate.account) { (imageNamePath) in
                if imageNamePath != nil {
                    if let image = UIImage(contentsOfFile: imageNamePath!) {
                        cell.imageView.image = image
                    }
                } else {
                     cell.imageView.image = UIImage.init(named: "file")
                }
            }
            
        } else {
            
            if activityPreview.isMimeTypeIcon {
                
                let source = activityPreview.source
                
                NCUtility.shared.convertSVGtoPNGWriteToUserData(svgUrlString: source, fileName: nil, width: 100, rewrite: false, account: appDelegate.account) { (imageNamePath) in
                    if imageNamePath != nil {
                        if let image = UIImage(contentsOfFile: imageNamePath!) {
                            cell.imageView.image = image
                        }
                    } else {
                        cell.imageView.image = UIImage.init(named: "file")
                    }
                }
                
            } else {
                
                if let activitySubjectRich = NCManageDatabase.shared.getActivitySubjectRich(account: account, idActivity: idActivity, id: fileId) {
                    
                    let fileNamePath = CCUtility.getDirectoryUserData() + "/" + activitySubjectRich.name
                    
                    if FileManager.default.fileExists(atPath: fileNamePath) {
                        
                        if let image = UIImage(contentsOfFile: fileNamePath) {
                            cell.imageView.image = image
                        }
                        
                    } else {
                        
                        NCCommunication.shared.downloadPreview(fileNamePathOrFileId: activityPreview.source, fileNamePreviewLocalPath: fileNamePath, widthPreview: 0, heightPreview: 0, etag: nil, useInternalEndpoint: false) { (account, imagePreview, imageIcon, imageOriginal, etag, errorCode, errorDescription) in
                            if errorCode == 0 && imagePreview != nil {
                                self.collectionView.reloadData()
                            }
                        }
                    }
                }
            }
        }
            
        return cell
    }
    
}

extension NCActivityTableViewCell: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 50, height: 50)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
    }
}
