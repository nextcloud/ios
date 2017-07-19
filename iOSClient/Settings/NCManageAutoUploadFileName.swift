//
//  NCManageAutoUploadFileName.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/07/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import Foundation

class NCManageAutoUploadFileName: XLFormViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
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

        // Section: Add File Name Type
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "addFileNameType", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: NSLocalizedString("_filenametype_photo_video_", comment: ""))
        row.value = CCUtility.getFileNameType(k_keyFileNameType)
        section.addFormRow(row)
        
        // Section: Rename File Name
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "maskFileName", rowType: XLFormRowDescriptorTypeAccount, title: NSLocalizedString("_filename_", comment: ""))
        
        let fileNameMask : String = CCUtility.getFileNameMask(k_keyFileNameMask)
        if fileNameMask.characters.count > 0 {
            row.value = fileNameMask
        }
        section.addFormRow(row)
        
        // Section: Preview File Name
        
        row = XLFormRowDescriptor(tag: "previewFileName", rowType: XLFormRowDescriptorTypeTextView, title: "")
        row.height = 180
        row.cellConfig.setObject(NCBrandColor.sharedInstance.tableBackground, forKey: "backgroundColor" as NSCopying)
        row.cellConfig.setObject(NCBrandColor.sharedInstance.tableBackground, forKey: "textView.backgroundColor" as NSCopying)
        
        row.disabled = true
        section.addFormRow(row)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
        
        if formRow.tag == "addFileNameType" {
            CCUtility.setFileNameType((formRow.value! as AnyObject).boolValue, key: k_keyFileNameType)
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
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.navigationBarText
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: NCBrandColor.sharedInstance.navigationBarText]
        
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        
        self.tableView.backgroundColor = NCBrandColor.sharedInstance.tableBackground
        
        self.reloadForm()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
    }
    
    func reloadForm() {
        
        self.form.delegate = nil
        
        let maskFileName : XLFormRowDescriptor = self.form.formRow(withTag: "maskFileName")!
        let previewFileName : XLFormRowDescriptor  = self.form.formRow(withTag: "previewFileName")!
        previewFileName.value = self.previewFileName(valueRename: maskFileName.value as? String)
        
        self.tableView.reloadData()
        self.form.delegate = self
    }
    
    //MARK: TableView
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        switch section {
            
        case 0:
            return "    " + NSLocalizedString("_add_filenametype_", comment: "")
        case 1:
            return "    " + NSLocalizedString("_rename_filename_", comment: "")
        case 2:
            return NSLocalizedString("_preview_filename_", comment: "")
        default:
            return ""
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        
        switch section {
            
            /*
             case 2:
             let buttonDestinationFolder : XLFormRowDescriptor  = self.form.formRow(withTag: "maskFileName")!
             let text = self.writePreviewFileName(buttonDestinationFolder)
             return text
             */
            
        default:
            return ""
        }
    }
    
    // MARK: - Utility
    
    func previewFileName(valueRename : String?) -> String {
        
        var returnString : String = ""
        
        if let valueRename = valueRename {
            
            let valueRenameTrimming = valueRename.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if valueRenameTrimming.characters.count > 0 {
                
                self.form.delegate = nil
                CCUtility.setFileNameMask(valueRenameTrimming, key: k_keyFileNameMask)
                self.form.delegate = self
                
                //returnString = CCUtility.createFileName(from: assets[0] as! PHAsset, keyFileName: k_keyFileNameMask, keyFileNameType: k_keyFileNameType)
                
            } else {
                
                CCUtility.setFileNameMask("", key: k_keyFileNameMask)
                //returnString = CCUtility.createFileName(from: assets[0] as! PHAsset, keyFileName: nil, keyFileNameType: k_keyFileNameType)
            }
            
        } else {
            
            CCUtility.setFileNameMask("", key: k_keyFileNameMask)
            //returnString = CCUtility.createFileName(from: assets[0] as! PHAsset, keyFileName: nil, keyFileNameType: k_keyFileNameType)
        }
        
        return NSLocalizedString("_preview_filename_", comment: "") + ":" + "\n\n" + returnString
    }
}
