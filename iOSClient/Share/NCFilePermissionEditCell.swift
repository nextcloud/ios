//
//  NCFilePermissionEditCell.swift
//  Nextcloud
//
//  Created by T-systems on 10/08/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

class NCFilePermissionEditCell: XLFormBaseCell, UITextFieldDelegate {
    
    @IBOutlet weak var seperator: UIView!
    @IBOutlet weak var seperatorMiddle: UIView!
    @IBOutlet weak var seperatorBottom: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var switchControl: UISwitch!
    @IBOutlet weak var cellTextField: UITextField!
    @IBOutlet weak var buttonLinkLabel: UIButton!
    let datePicker = UIDatePicker()
    var expirationDateText: String!
    var expirationDate: NSDate!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.cellTextField.delegate = self
        self.cellTextField.isEnabled = false
        self.selectionStyle = .none
        switchControl.addTarget(self, action: #selector(switchChanged), for: UIControl.Event.valueChanged)
        self.backgroundColor = NCBrandColor.shared.secondarySystemGroupedBackground
        self.titleLabel.textColor = NCBrandColor.shared.label
        self.cellTextField.attributedPlaceholder = NSAttributedString(string: "",
                                                               attributes: [NSAttributedString.Key.foregroundColor: NCBrandColor.shared.gray60])
        self.cellTextField.textColor = NCBrandColor.shared.singleTitleColorButton
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
    }
    
    @objc func changeTheming() {
        self.backgroundColor = NCBrandColor.shared.secondarySystemGroupedBackground
        self.titleLabel.textColor = NCBrandColor.shared.iconColor
    }
    
    override func configure() {
        super.configure()
    }
    
    override func update() {
        super.update()
                
        if rowDescriptor.tag ==  "kNMCFilePermissionCellEditingCanShare" {
            self.seperatorMiddle.isHidden = true
            self.seperatorBottom.isHidden = true
            self.cellTextField.isHidden = true
        }
        if rowDescriptor.tag == "kNMCFilePermissionEditCellLinkLabel" {
            self.switchControl.isHidden = true
            self.cellTextField.isEnabled = true
            self.seperatorBottom.isHidden = true
        }
        if rowDescriptor.tag == "kNMCFilePermissionEditCellLinkLabel" {
            self.switchControl.isHidden = true
        }
        
        if rowDescriptor.tag == "kNMCFilePermissionEditCellExpiration" {
            self.seperator.isHidden = true
            setDatePicker(sender: self.cellTextField)
        }
        
        if rowDescriptor.tag == "kNMCFilePermissionEditPasswordCellWithText" {
            self.seperatorMiddle.isHidden = true
            self.seperator.isHidden = true
        }
        
        if rowDescriptor.tag == "kNMCFilePermissionEditCellHideDownload" {
            self.seperator.isHidden = true
            self.seperatorMiddle.isHidden = true
        }
        
        if  rowDescriptor.tag == "kNMCFilePermissionEditCellEditingCanShare" {
            self.seperator.isHidden = true
            self.seperatorBottom.isHidden = true
        }
    }
    
    @objc func switchChanged(mySwitch: UISwitch) {
        let isOn = mySwitch.isOn
        if isOn {
            //on
            self.rowDescriptor.value = isOn
            self.cellTextField.isEnabled = true
            cellTextField.delegate = self
        } else {
            self.rowDescriptor.value = isOn
            self.cellTextField.isEnabled = false
            if rowDescriptor.tag == "kNMCFilePermissionEditCellExpiration" || rowDescriptor.tag == "kNMCFilePermissionEditCellPassword" {
                self.cellTextField.text = ""
            }
        }
        if rowDescriptor.tag == "kNMCFilePermissionEditPasswordCellWithText" {
            seperatorBottom.isHidden = isOn
            seperatorMiddle.isHidden = !isOn
        }
        if rowDescriptor.tag == "kNMCFilePermissionEditCellExpiration" {
            seperatorBottom.isHidden = isOn
            seperatorMiddle.isHidden = !isOn
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if self.cellTextField == textField {
            if let rowDescriptor = rowDescriptor, let text = self.cellTextField.text {

                if (text + " ").isEmpty == false {
                    rowDescriptor.value = self.cellTextField.text! + string
                } else {
                    rowDescriptor.value = nil
                }
            }
        }
        
        self.formViewController().textField(textField, shouldChangeCharactersIn: range, replacementString: string)
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.formViewController()?.textFieldShouldReturn(textField)
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        self.formViewController()?.textFieldShouldClear(textField)
        return true
    }
    
    override class func formDescriptorCellHeight(for rowDescriptor: XLFormRowDescriptor!) -> CGFloat {
        return 30
    }
    
    override func formDescriptorCellDidSelected(withForm controller: XLFormViewController!) {
        self.selectionStyle = .none
    }
    
    func setDatePicker(sender: UITextField) {
        //Format Date
        datePicker.datePickerMode = .date
        datePicker.minimumDate = Date()
        //ToolBar
        let toolbar = UIToolbar();
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneDatePicker));
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelDatePicker));

        toolbar.setItems([doneButton,spaceButton,cancelButton], animated: false)

        sender.inputAccessoryView = toolbar
        sender.inputView = datePicker
    }
    
    @objc func doneDatePicker() {
        let dateFormatter = DateFormatter()
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.dateStyle = .medium
        self.expirationDateText = dateFormatter.string(from: datePicker.date as Date)
        
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        self.expirationDate = datePicker.date as NSDate
        self.cellTextField.text = self.expirationDateText
        self.rowDescriptor.value = self.expirationDate
        self.cellTextField.endEditing(true)
    }

    @objc func cancelDatePicker() {
        self.cellTextField.endEditing(true)
    }
}
