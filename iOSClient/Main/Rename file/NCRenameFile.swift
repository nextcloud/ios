//
//  NCRenameFile.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/02/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation
import NCCommunication

class NCRenameFile: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var separatorHeightContraint: NSLayoutConstraint!
    @IBOutlet weak var previewFile: UIImageView!
    @IBOutlet weak var fileNameWithoutExt: UITextField!
    @IBOutlet weak var point: UILabel!
    @IBOutlet weak var ext: UITextField!
    @IBOutlet weak var fileNameWithoutExtTrailingContraint: NSLayoutConstraint!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var renameButton: UIButton!

    var metadata: tableMetadata?
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let metadata = self.metadata {
                
            fileNameWithoutExt.text = metadata.fileNameWithoutExt
            ext.text = metadata.ext

            if metadata.directory {
                
                previewFile.image = NCCollectionCommon.images.cellFolderImage
                
                ext.isHidden = true
                point.isHidden = true
                fileNameWithoutExtTrailingContraint.constant = 20
                
            } else {
                
                if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                    previewFile.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                } else {
                    if metadata.iconName.count > 0 {
                        previewFile.image = UIImage.init(named: metadata.iconName)
                    } else {
                        previewFile.image = NCCollectionCommon.images.cellFileImage
                    }
                }
                                
                fileNameWithoutExtTrailingContraint.constant = 90
            }
        }
                
        titleLabel.text = NSLocalizedString("_rename_file_", comment: "")
        separatorHeightContraint.constant = 0.3
        
        cancelButton.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        cancelButton.setTitleColor(.gray, for: .normal)
        cancelButton.layer.cornerRadius = 15
        cancelButton.layer.masksToBounds = true
        cancelButton.layer.backgroundColor =  NCBrandColor.shared.graySoft.withAlphaComponent(0.3).cgColor
        cancelButton.layer.borderWidth = 0.3
        cancelButton.layer.borderColor = UIColor.gray.cgColor
        
        renameButton.setTitle(NSLocalizedString("_rename_", comment: ""), for: .normal)
        renameButton.setTitleColor(NCBrandColor.shared.brandText, for: .normal)
        renameButton.layer.cornerRadius = 15
        renameButton.layer.masksToBounds = true
        renameButton.layer.backgroundColor = NCBrandColor.shared.brand.cgColor
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if metadata == nil {
            dismiss(animated: true)
        }
    }
    
    // MARK: - Action
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func rename(_ sender: Any) {

        guard let metadata = metadata else { return }
        var newFileNameWithoutExt = ""
        var newExt = ""
        var fileNameNew = ""
        
        if fileNameWithoutExt.text == nil || fileNameWithoutExt.text?.count == 0 {
            self.fileNameWithoutExt.text = metadata.fileNameWithoutExt
            return
        } else {
            newFileNameWithoutExt = fileNameWithoutExt.text!
        }
        
        if metadata.directory {
            
            fileNameNew = newFileNameWithoutExt
            renameMetadata(metadata, fileNameNew: fileNameNew)
            
        } else {
            
            if ext.text == nil || ext.text?.count == 0 {
                self.ext.text = metadata.ext
                return
            } else {
                newExt = ext.text!
            }
            
            if newExt != metadata.ext {
                
            } else {
            
                fileNameNew = newFileNameWithoutExt + "." + newExt
                renameMetadata(metadata, fileNameNew: fileNameNew)
            }
        }
    }
    
    // MARK: - Networking

    func renameMetadata(_ metadata: tableMetadata, fileNameNew: String) {
        
        NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew, urlBase: metadata.urlBase, viewController: self) { (errorCode, errorDescription) in
            if errorCode == 0 {
                self.dismiss(animated: true)
            } else {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
}
