//
//  PrivacySettingsViewController.swift
//  Nextcloud
//
//  Created by A200073704 on 25/04/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import AppTrackingTransparency
import AdSupport

class PrivacySettingsViewController: XLFormViewController{
    
    @objc public var isShowSettingsButton: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("_privacy_settings_title_", comment: "")
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        
        let nib = UINib(nibName: "CustomSectionHeader", bundle: nil)
        self.tableView.register(nib, forHeaderFooterViewReuseIdentifier: "customSectionHeader")
        isShowSettingsButton = UserDefaults.standard.bool(forKey: "showSettingsButton")
        self.navigationController?.navigationBar.tintColor = NCBrandColor.shared.brand
        changeTheming()
    }
    
    @objc func changeTheming() {
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorColor = .none
        tableView.separatorColor = .clear
        tableView.reloadData()
        initializeForm()
    }
    
    //MARK: XLForm
    func initializeForm() {
        let form : XLFormDescriptor = XLFormDescriptor() as XLFormDescriptor
        form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow
        
        var section : XLFormSectionDescriptor
        var row : XLFormRowDescriptor
        
        // Section: Destination Folder
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("", comment: "").uppercased())
        section.footerTitle = "                             "
        form.addFormSection(section)
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("", comment: "").uppercased())
        section.footerTitle = NSLocalizedString("_privacy_settings_help_text_", comment: "")
        form.addFormSection(section)
        
        //custom cell
        section = XLFormSectionDescriptor.formSection(withTitle: "")
        section.footerTitle = NSLocalizedString("_required_data_collection_help_text_", comment: "")
        form.addFormSection(section)
        
        XLFormViewController.cellClassesForRowDescriptorTypes()["RequiredDataCollectionCustomCellType"] = RequiredDataCollectionSwitch.self
        
        row = XLFormRowDescriptor(tag: "ButtonDestinationFolder", rowType: "RequiredDataCollectionCustomCellType", title: "")
        row.cellConfig["requiredDataCollectionSwitchControl.onTintColor"] = NCBrandColor.shared.brand
        row.cellConfig["cellLabel.textAlignment"] = NSTextAlignment.left.rawValue
        row.cellConfig["cellLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["cellLabel.textColor"] = UIColor.label //photos
        row.cellConfig["cellLabel.text"] = NSLocalizedString("_required_data_collection_", comment: "")
        section.addFormRow(row)
        
        section = XLFormSectionDescriptor.formSection(withTitle: NSLocalizedString("", comment: "").uppercased())
        section.footerTitle = NSLocalizedString("_analysis_data_acqusition_help_text_", comment: "")
        form.addFormSection(section)
        
        XLFormViewController.cellClassesForRowDescriptorTypes()["AnalysisDataCollectionCustomCellType"] = AnalysisDataCollectionSwitch.self
        
        row = XLFormRowDescriptor(tag: "AnalysisDataCollectionSwitch", rowType: "AnalysisDataCollectionCustomCellType", title: "")
        row.cellConfig["analysisDataCollectionSwitchControl.onTintColor"] = NCBrandColor.shared.brand
        row.cellConfig["cellLabel.textAlignment"] = NSTextAlignment.left.rawValue
        row.cellConfig["cellLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["cellLabel.textColor"] = UIColor.label //photos
        row.cellConfig["cellLabel.text"] = NSLocalizedString("_analysis_data_acqusition_", comment: "")
        if(UserDefaults.standard.bool(forKey: "isAnalysisDataCollectionSwitchOn")){
            row.cellConfigAtConfigure["analysisDataCollectionSwitchControl.on"] = 1
        }else {
            row.cellConfigAtConfigure["analysisDataCollectionSwitchControl.on"] = 0
        }
        
        section.addFormRow(row)
        
        XLFormViewController.cellClassesForRowDescriptorTypes()["SaveSettingsButton"] = SaveSettingsCustomButtonCell.self
        
        section = XLFormSectionDescriptor.formSection(withTitle: "")
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "SaveSettingsButton", rowType: "SaveSettingsButton", title: "")
        row.cellConfig["backgroundColor"] = UIColor.clear
        
        if(isShowSettingsButton){
            section.addFormRow(row)
        }
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
        
        if formRow.tag == "SaveSettingsButton" {
            print("save settings clicked")
            //TODO save button state and leave the page
            self.navigationController?.popViewController(animated: true)
            
        }
        if formRow.tag == "AnalysisDataCollectionSwitch"{
            if (formRow.value! as AnyObject).boolValue {
                if #available(iOS 14, *) {
                    ATTrackingManager.requestTrackingAuthorization(completionHandler: { (status) in
                        if status == .denied {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                                return
                            }
                            if UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url, options: [:])
                            }
                        }
                    })
                }
            }
            UserDefaults.standard.set((formRow.value! as AnyObject).boolValue, forKey: "isAnalysisDataCollectionSwitchOn")
        }
    }
}
