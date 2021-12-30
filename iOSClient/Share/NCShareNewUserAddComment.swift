//
//  NCShareNewUserAddComment.swift
//  Nextcloud
//
//  Created by TSI-mc on 21/06/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//  Copyright © 2021 TSI-mc. All rights reserved.
//

import UIKit
import NCCommunication
import SVGKit

class NCShareNewUserAddComment: UIViewController, UITextViewDelegate, NCShareNetworkingDelegate {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var folderImageView: UIImageView!
    @IBOutlet weak var labelFileName: UILabel!
    @IBOutlet weak var favorite: UIButton!
    @IBOutlet weak var labelDescription: UILabel!
    @IBOutlet weak var labelSharing: UILabel!
    @IBOutlet weak var labelNote: UILabel!
    @IBOutlet weak var commentTextView: UITextView!
    @IBOutlet weak var commentContainerView: UIView!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnSendShare: UIButton!
    @IBOutlet weak var buttonContainerView: UIView!
    
    public var metadata: tableMetadata?
    public var sharee: NCCommunicationSharee?
    private var networking: NCShareNetworking?
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var permission: Int = 0
    var password: String?
    var label: String?
    var expirationDate: String?
    var hideDownload = false
    
    var creatingShare = false
    var note = ""
    var shareeEmail: String?
    public var tableShare: tableShare?
    var isUpdating = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata!.ocId, etag: metadata!.etag)) {
            self.imageView.image = getImageMetadata(metadata!)
            self.imageView.contentMode = .scaleAspectFill
            self.folderImageView.isHidden = true
        } else {
            if metadata!.directory {
                self.folderImageView.image = UIImage.init(named: "folder")!
            } else if metadata!.iconName.count > 0 {
                self.folderImageView.image = UIImage.init(named: metadata!.iconName)
            } else {
                self.folderImageView.image = UIImage.init(named: "file")
            }
        }
        self.favorite.layoutIfNeeded()
        self.labelFileName.text = self.metadata?.fileNameView
        if metadata!.favorite {
            self.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite, size: 24), for: .normal)
        } else {
            self.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.textInfo, size: 24), for: .normal)
        }
        self.labelDescription.text = CCUtility.transformedSize(metadata!.size) + ", " + CCUtility.dateDiff(metadata!.date as Date)
        labelSharing.text = NSLocalizedString("_sharing_", comment: "")
        labelNote.text = NSLocalizedString("_share_note_recipient_", comment: "")
        
        commentContainerView.layer.borderWidth = 1
        commentContainerView.layer.cornerRadius = 4.0
        
        btnCancel.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        btnCancel.layer.cornerRadius = 10
        btnCancel.layer.masksToBounds = true
        btnCancel.layer.borderWidth = 1
        
        btnSendShare.setTitle(NSLocalizedString("_send_share_", comment: ""), for: .normal)
        btnSendShare.layer.cornerRadius = 10
        btnSendShare.layer.masksToBounds = true
        
        commentTextView.showsVerticalScrollIndicator = false
        setTitle()
        changeTheming()
        networking = NCShareNetworking.init(metadata: metadata!, urlBase: appDelegate.urlBase, view: self.view, delegate: self)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        buttonContainerView.addShadow(location: .top)
    }
    
    func setTitle() {
        let defaultTitle = NSLocalizedString("_sharing_", comment: "")
        title = isUpdating ? (tableShare?.shareWith ?? defaultTitle) : (sharee?.shareWith ?? defaultTitle)
    }
    
    @objc func changeTheming() {
        self.view.backgroundColor = NCBrandColor.shared.secondarySystemGroupedBackground
        self.commentTextView.backgroundColor = NCBrandColor.shared.secondarySystemGroupedBackground
        self.labelFileName.textColor = NCBrandColor.shared.label
        self.labelDescription.textColor = NCBrandColor.shared.systemGray
        commentTextView.textColor = NCBrandColor.shared.label
        btnCancel.setTitleColor(NCBrandColor.shared.label, for: .normal)
        btnCancel.layer.borderColor = NCBrandColor.shared.label.cgColor
        btnCancel.backgroundColor = .clear
        buttonContainerView.backgroundColor = NCBrandColor.shared.secondarySystemGroupedBackground
        btnSendShare.setBackgroundColor(NCBrandColor.shared.customer, for: .normal)
        btnSendShare.setTitleColor(.white, for: .normal)
        commentContainerView.layer.borderColor = NCBrandColor.shared.label.cgColor
    }
    
    @IBAction func cancelClicked(_ sender: Any) {
        popToShare()
    }
    
    @IBAction func sendShareClicked(_ sender: Any) {
        let message = commentTextView.text.trimmingCharacters(in: .whitespaces)
        self.note = message
        if isUpdating {
            self.networking?.updateShare(idShare: tableShare!.idShare, password: nil, permissions: self.tableShare!.permissions, note: message, label: nil, expirationDate: nil, hideDownload: tableShare!.hideDownload)
        } else {
            self.networking?.createShare(shareWith: sharee!.shareWith, shareType: sharee!.shareType, metadata: self.metadata!)
        }
        self.creatingShare = true
    }
    
    //MARK: - Image
    
    func getImageMetadata(_ metadata: tableMetadata) -> UIImage? {
                
        if let image = getImage(metadata: metadata) {
            return image
        }
        
        if metadata.typeFile == NCGlobal.shared.metadataTypeFileVideo && !metadata.hasPreview {
            NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.typeFile)
        }
        
        if CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
            if let imagePreviewPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag) {
                return UIImage.init(contentsOfFile: imagePreviewPath)
            }
        }
        
        return nil
    }
    
    //MARK :- Action methods
    
    @IBAction func touchUpInsideFavorite(_ sender: UIButton) {
        if let metadata = self.metadata {
            NCNetworking.shared.favoriteMetadata(metadata) { (errorCode, errorDescription) in
                if errorCode == 0 {
                    if !metadata.favorite {
                        self.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite, size: 24), for: .normal)
                        self.metadata?.favorite = true
                    } else {
                        self.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.textInfo, size: 24), for: .normal)
                        self.metadata?.favorite = false
                    }
                } else {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }
    }
    
    private func getImage(metadata: tableMetadata) -> UIImage? {
        
        let ext = CCUtility.getExtension(metadata.fileNameView)
        var image: UIImage?
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && metadata.typeFile == NCGlobal.shared.metadataTypeFileImage {
           
            let previewPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
            let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            
            if ext == "GIF" {
                if !FileManager().fileExists(atPath: previewPath) {
                    NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.typeFile)
                }
                image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: imagePath))
            } else if ext == "SVG" {
                if let svgImage = SVGKImage(contentsOfFile: imagePath) {
                    let scale = svgImage.size.height / svgImage.size.width
                    svgImage.size = CGSize(width: NCGlobal.shared.sizePreview, height: (NCGlobal.shared.sizePreview * Int(scale)))
                    if let image = svgImage.uiImage {
                        if !FileManager().fileExists(atPath: previewPath) {
                            do {
                                try image.pngData()?.write(to: URL(fileURLWithPath: previewPath), options: .atomic)
                            } catch { }
                        }
                        return image
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            } else {
                NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.typeFile)
                image = UIImage.init(contentsOfFile: imagePath)
            }
        }
        
        return image
    }
    
    //MARK: - NCShareNetworkingDelegate
    
    func popToShare() {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    func readShareCompleted() {
        popToShare()
    }
    
    func shareCompleted() {}
    
    func shareCompleted(createdShareId: Int?) {
        if self.creatingShare {
            self.appDelegate.shares = NCManageDatabase.shared.getTableShares(account: self.metadata!.account)
            if let id = createdShareId {
                networking?.updateShare(idShare: id, password: password, permissions: permission, note: nil, label: label, expirationDate: expirationDate, hideDownload: hideDownload)
            } else {
                popToShare()
            }
        }
    }
    
    func unShareCompleted() {}
    
    func updateShareWithError(idShare: Int) {
        popToShare()
    }
    
    func getSharees(sharees: [NCCommunicationSharee]?) {}
    
}
