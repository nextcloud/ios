//
//  NCRenameFile.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/02/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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

class NCRenameFile: UIViewController, UITextFieldDelegate {

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
    var disableChangeExt: Bool = false
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let metadata = self.metadata {
                
            titleLabel.text = NSLocalizedString("_rename_file_", comment: "")
            separatorHeightContraint.constant = 0.3
            
            fileNameWithoutExt.text = metadata.fileNameWithoutExt
            fileNameWithoutExt.delegate = self
            fileNameWithoutExt.becomeFirstResponder()
            
            ext.text = metadata.ext
            ext.delegate = self
            if disableChangeExt {
                ext.isEnabled = false
                ext.textColor = .lightGray
            }

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
        previewFile.layer.cornerRadius = 10
        previewFile.layer.masksToBounds = true
                
        cancelButton.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        cancelButton.setTitleColor(.gray, for: .normal)
        cancelButton.layer.cornerRadius = 15
        cancelButton.layer.masksToBounds = true
        cancelButton.layer.backgroundColor =  NCBrandColor.shared.graySoft.withAlphaComponent(0.2).cgColor
        cancelButton.layer.borderWidth = 0.3
        cancelButton.layer.borderColor = UIColor.gray.cgColor
        
        renameButton.setTitle(NSLocalizedString("_rename_", comment: ""), for: .normal)
        renameButton.setTitleColor(NCBrandColor.shared.brandText, for: .normal)
        renameButton.layer.cornerRadius = 15
        renameButton.layer.masksToBounds = true
        renameButton.layer.backgroundColor = NCBrandColor.shared.brand.cgColor
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if metadata == nil {
            dismiss(animated: true)
        }
        
        fileNameWithoutExt.selectAll(nil)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        rename(textField)
        return true
    }
    
    // MARK: - Action
    
    @IBAction func cancel(_ sender: Any) {
        
        dismiss(animated: true)
    }
    
    @IBAction func rename(_ sender: Any) {

        guard let metadata = metadata else { return }
        var fileNameWithoutExtNew = ""
        var extNew = ""
        var fileNameNew = ""
        
        if fileNameWithoutExt.text == nil || fileNameWithoutExt.text?.count == 0 {
            self.fileNameWithoutExt.text = metadata.fileNameWithoutExt
            return
        } else {
            fileNameWithoutExtNew = fileNameWithoutExt.text!
        }
        
        if metadata.directory {
            
            fileNameNew = fileNameWithoutExtNew
            renameMetadata(metadata, fileNameNew: fileNameNew)
            
        } else {
            
            if ext.text == nil || ext.text?.count == 0 {
                self.ext.text = metadata.ext
                return
            } else {
                extNew = ext.text!
            }
            
            if extNew != metadata.ext {
                
                let message = String(format: NSLocalizedString("_rename_ext_message_", comment: ""), extNew, metadata.ext)
                let alertController = UIAlertController(title: NSLocalizedString("_rename_ext_title_", comment: ""), message: message, preferredStyle: .alert)
                            
                var title = NSLocalizedString("_use_", comment: "") + " ." + extNew
                alertController.addAction(UIAlertAction(title: title, style: .default, handler: { action in
                    
                    fileNameNew = fileNameWithoutExtNew + "." + extNew
                    self.renameMetadata(metadata, fileNameNew: fileNameNew)
                }))
                
                title = NSLocalizedString("_keep_", comment: "") + " ." + metadata.ext
                alertController.addAction(UIAlertAction(title: title, style: .default, handler: { action in
                    self.ext.text = metadata.ext
                }))
                
                self.present(alertController, animated: true)
                
            } else {
            
                fileNameNew = fileNameWithoutExtNew + "." + extNew
                renameMetadata(metadata, fileNameNew: fileNameNew)
            }
        }
    }
    
    // MARK: - Networking

    func renameMetadata(_ metadata: tableMetadata, fileNameNew: String) {
        
        NCUtility.shared.startActivityIndicator(view: nil)
        
        NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew, urlBase: metadata.urlBase, viewController: self) { (errorCode, errorDescription) in
            
            NCUtility.shared.stopActivityIndicator()
            
            if errorCode == 0 {
                
                self.dismiss(animated: true)
                
            } else {
                
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
}
