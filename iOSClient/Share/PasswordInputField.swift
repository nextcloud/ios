//
//  PasswordInputField.swift
//  Nextcloud
//
//  Created by Sumit on 10/06/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation

class PasswordInputField: XLFormBaseCell,UITextFieldDelegate {
    
    @IBOutlet weak var fileNameInputTextField: UITextField!
    @IBOutlet weak var separatorBottom: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        fileNameInputTextField.isSecureTextEntry = true
        fileNameInputTextField.delegate = self
        separatorBottom.backgroundColor = NCBrandColor.shared.systemGray4
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func configure() {
        super.configure()
       // fileNameInputTextField.isEnabled = false
        
    }
    
    override func update() {
        super.update()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

        if fileNameInputTextField == textField {
            if let rowDescriptor = rowDescriptor, let text = self.fileNameInputTextField.text {

                if (text + " ").isEmpty == false {
                    rowDescriptor.value = self.fileNameInputTextField.text! + string
                } else {
                    rowDescriptor.value = nil
                }
            }
        }

         self.formViewController().textField(textField, shouldChangeCharactersIn: range, replacementString: string)
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.formViewController()?.textFieldShouldReturn(fileNameInputTextField)
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        self.formViewController()?.textFieldShouldClear(fileNameInputTextField)
        return true
    }
    
    override class func formDescriptorCellHeight(for rowDescriptor: XLFormRowDescriptor!) -> CGFloat {
        return 45
    }
}
