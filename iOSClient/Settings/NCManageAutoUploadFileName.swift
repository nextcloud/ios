//
//  NCManageAutoUploadFileName.swift
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 19/07/17.
//  Copyright (c) 2017 TWS. All rights reserved.
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

class NCManageAutoUploadFileName: XLFormViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let dateExample = Date()
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initializeForm()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.initializeForm()
    }
        
    func initializeForm() {
        
        let form : XLFormDescriptor = XLFormDescriptor(title: NSLocalizedString("_autoupload_filename_title_", comment: "")) as XLFormDescriptor
        form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow
        
        var section : XLFormSectionDescriptor
        var row : XLFormRowDescriptor

        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        // Maintain the original fileName
        
        row = XLFormRowDescriptor(tag: "maintainOriginalFileName", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_maintain_original_filename_", comment: ""))
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        row.value = CCUtility.getOriginalFileName(k_keyFileNameOriginalAutoUpload)
        section.addFormRow(row)
        
        // Add File Name Type
        
        row = XLFormRowDescriptor(tag: "addFileNameType", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_add_filenametype_", comment: ""))
        row.hidden = "$\("maintainOriginalFileName") == 1"
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        row.value = CCUtility.getFileNameType(k_keyFileNameAutoUploadType)
        section.addFormRow(row)
                
        // Section: Rename File Name
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "maskFileName", rowType: XLFormRowDescriptorTypeAccount, title: (NSLocalizedString("_filename_", comment: ""))+":")
        row.hidden = "$\("maintainOriginalFileName") == 1"
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        let fileNameMask : String = CCUtility.getFileNameMask(k_keyFileNameAutoUploadMask)
        if fileNameMask.count > 0 {
            row.value = fileNameMask
        }
        section.addFormRow(row)
        
        // Section: Preview File Name
        
        row = XLFormRowDescriptor(tag: "previewFileName", rowType: XLFormRowDescriptorTypeTextView, title: "")
        row.cellConfig.setObject(UIFont.systemFont(ofSize: 15.0), forKey: "textLabel.font" as NSCopying)
        row.height = 180
        row.cellConfig.setObject(NCBrandColor.sharedInstance.backgroundView, forKey: "backgroundColor" as NSCopying)
        row.cellConfig.setObject(NCBrandColor.sharedInstance.backgroundView, forKey: "textView.backgroundColor" as NSCopying)
        
        row.disabled = true
        section.addFormRow(row)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
        
        if formRow.tag == "addFileNameType" {
            CCUtility.setFileNameType((formRow.value! as AnyObject).boolValue, key: k_keyFileNameAutoUploadType)
            self.reloadForm()
        }
        else if formRow.tag == "maintainOriginalFileName" {
            CCUtility.setOriginalFileName((formRow.value! as AnyObject).boolValue, key:k_keyFileNameOriginalAutoUpload)
            self.reloadForm()
        }
        else if formRow.tag == "maskFileName" {
            
            let fileName = formRow.value as? String
            
            self.form.delegate = nil
            
            if let fileName = fileName {
                formRow.value = CCUtility.removeForbiddenCharactersServer(fileName)
            }
            
            self.form.delegate = self
            
            let previewFileName : XLFormRowDescriptor  = self.form.formRow(withTag: "previewFileName")!
            previewFileName.value = self.previewFileName(valueRename: formRow.value as? String)
            
            // reload cell
            if fileName != nil {
                
                if newValue as! String != formRow.value as! String {
                    
                    self.reloadFormRow(formRow)
                    
                    appDelegate.messageNotification("_info_", description: "_forbidden_characters_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: 0)
                }
            }
            
            self.reloadFormRow(previewFileName)
        }
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: NCBrandColor.sharedInstance.brandText]
        
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        
        self.tableView.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        
        self.reloadForm()
    }
    
    func reloadForm() {
        
        self.form.delegate = nil
        
        let maskFileName : XLFormRowDescriptor = self.form.formRow(withTag: "maskFileName")!
        let previewFileName : XLFormRowDescriptor  = self.form.formRow(withTag: "previewFileName")!
        previewFileName.value = self.previewFileName(valueRename: maskFileName.value as? String)
        
        self.tableView.reloadData()
        self.form.delegate = self
    }
    
    // MARK: - Utility
    
    func previewFileName(valueRename : String?) -> String {
        
        var returnString : String = ""
        
        if CCUtility.getOriginalFileName(k_keyFileNameOriginalAutoUpload) {
            
            return (NSLocalizedString("_filename_", comment: "") + ": IMG_0001.JPG")
            
        } else if let valueRename = valueRename {
            
            let valueRenameTrimming = valueRename.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if valueRenameTrimming.count > 0 {
                
                self.form.delegate = nil
                CCUtility.setFileNameMask(valueRename, key: k_keyFileNameAutoUploadMask)
                self.form.delegate = self
                
                returnString = CCUtility.createFileName("IMG_0001.JPG", fileDate: dateExample, fileType: PHAssetMediaType.image, keyFileName: k_keyFileNameAutoUploadMask, keyFileNameType: k_keyFileNameAutoUploadType, keyFileNameOriginal: k_keyFileNameOriginalAutoUpload)

            } else {
                
                CCUtility.setFileNameMask("", key: k_keyFileNameAutoUploadMask)
                returnString = CCUtility.createFileName("IMG_0001.JPG", fileDate: dateExample, fileType: PHAssetMediaType.image, keyFileName: nil, keyFileNameType: k_keyFileNameAutoUploadType, keyFileNameOriginal: k_keyFileNameOriginalAutoUpload)
            }
            
        } else {
            
            CCUtility.setFileNameMask("", key: k_keyFileNameAutoUploadMask)
            returnString = CCUtility.createFileName("IMG_0001.JPG", fileDate: dateExample, fileType: PHAssetMediaType.image, keyFileName: nil, keyFileNameType: k_keyFileNameAutoUploadType, keyFileNameOriginal: k_keyFileNameOriginalAutoUpload)
        }
        
        return String(format: NSLocalizedString("_preview_filename_", comment: ""), "MM,MMM,DD,YY,YYYY and HH,hh,mm,ss,ampm") + ":" + "\n\n" + returnString
    }
}
