//
//  NCShareTextInputCell.swift
//  Nextcloud
//
//  Created by T-systems on 20/09/21.
//  Copyright © 2021 Kunal. All rights reserved.
//

import UIKit

class NCShareTextInputCell: XLFormBaseCell, UITextFieldDelegate {
    
    @IBOutlet weak var seperator: UIView!
    @IBOutlet weak var seperatorBottom: UIView!
    @IBOutlet weak var cellTextField: UITextField!
    @IBOutlet weak var calendarImageView: UIImageView!
    
    let datePicker = UIDatePicker()
    var expirationDateText: String!
    var expirationDate: NSDate!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.cellTextField.delegate = self
        self.cellTextField.isEnabled = true
        calendarImageView.image = UIImage(named: "calender")?.imageColor(NCBrandColor.shared.brandElement) 
        self.selectionStyle = .none
        self.backgroundColor = NCBrandColor.shared.secondarySystemGroupedBackground
        self.cellTextField.attributedPlaceholder = NSAttributedString(string: "",
                                                               attributes: [NSAttributedString.Key.foregroundColor: NCBrandColor.shared.gray60])
        self.cellTextField.textColor = NCBrandColor.shared.singleTitleColorButton
    }
    
    override func configure() {
        super.configure()
    }
    
    override func update() {
        super.update()
        calendarImageView.isHidden = rowDescriptor.tag != "NCShareTextInputCellExpiry"
        if rowDescriptor.tag == "NCShareTextInputCellExpiry" {
            seperator.isHidden = true
            setDatePicker(sender: self.cellTextField)
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
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        rowDescriptor.value = cellTextField.text
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
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
            datePicker.sizeToFit()
        }
        //ToolBar
        let toolbar = UIToolbar();
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneDatePicker));
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelDatePicker));

        toolbar.setItems([cancelButton, spaceButton, doneButton], animated: false)

        sender.inputAccessoryView = toolbar
        sender.inputView = datePicker
    }
    
    @objc func doneDatePicker() {
        let dateFormatter = DateFormatter()
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.dateStyle = .medium
        dateFormatter.dateFormat = NCShareAdvancePermission.displayDateFormat
        
        var expiryDate = dateFormatter.string(from: datePicker.date)
        expiryDate = expiryDate.replacingOccurrences(of: "..", with: ".")
        self.expirationDateText = expiryDate
        
        self.expirationDate = datePicker.date as NSDate
        self.cellTextField.text = self.expirationDateText
        self.rowDescriptor.value = self.expirationDate
        self.cellTextField.endEditing(true)
    }

    @objc func cancelDatePicker() {
        self.cellTextField.endEditing(true)
    }
}

class NCSeparatorCell: XLFormBaseCell {
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    override func update() {
        super.update()
        self.selectionStyle = .none
    }
}
