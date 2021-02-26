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

    @IBOutlet weak var previewFile: UIImageView!
    
    @IBOutlet weak var fileNameWithoutExt: UITextField!
    @IBOutlet weak var point: UILabel!
    @IBOutlet weak var ext: UITextField!

    @IBOutlet weak var fileNameWithoutExtTrailingContraint: NSLayoutConstraint!

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
                
        title = NSLocalizedString("_rename_file_", comment: "")
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_rename_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(rename))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if metadata == nil {
            dismiss(animated: true)
        }
    }
    
    // MARK: - Action
    
    @objc func cancel() {
        dismiss(animated: true)
    }
    
    @objc func rename() {
        
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
