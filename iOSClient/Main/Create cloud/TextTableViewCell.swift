//
//  TextTableViewCell.swift
//  Nextcloud
//
//  Created by Ashu on 23/04/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

class TextTableViewCell: XLFormBaseCell, UITextFieldDelegate {

    @IBOutlet weak var fileNameTextField: UITextField!
    @IBOutlet weak var topLineView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        fileNameTextField.delegate = self
        topLineView.backgroundColor = UIColor.secondarySystemBackground
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func configure() {
        super.configure()
    }
    
    override func update() {
        super.update()
        if (rowDescriptor.tag == "maskFileName"){
            topLineView.isHidden = true
        }else{
            topLineView.isHidden = false
        }
        
        fileNameTextField.tintColor = UIColor.systemGray
        fileNameTextField.selectedTextRange = fileNameTextField.textRange(from: fileNameTextField.beginningOfDocument, to: fileNameTextField.endOfDocument)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

        if fileNameTextField == textField {
            if let rowDescriptor = rowDescriptor, let text = self.fileNameTextField.text {

                if (text + " ").isEmpty == false {
                    rowDescriptor.value = self.fileNameTextField.text! + string
                } else {
                    rowDescriptor.value = nil
                }
            }
        }

         self.formViewController().textField(textField, shouldChangeCharactersIn: range, replacementString: string)
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.formViewController()?.textFieldShouldReturn(fileNameTextField)
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        self.formViewController()?.textFieldShouldClear(fileNameTextField)
        rowDescriptor.value = nil

        self.formViewController().textField(textField, shouldChangeCharactersIn: NSRange.init().self, replacementString: "")
        return true
    }
    
    override class func formDescriptorCellHeight(for rowDescriptor: XLFormRowDescriptor!) -> CGFloat {
        return 45
    }
}

extension UITextField {
    @IBInspectable var placeholderColor: UIColor {
        get {
            return attributedPlaceholder?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor ?? .clear
        }
        set {
            guard let attributedPlaceholder = attributedPlaceholder else { return }
            let attributes: [NSAttributedString.Key: UIColor] = [.foregroundColor: newValue]
            self.attributedPlaceholder = NSAttributedString(string: attributedPlaceholder.string, attributes: attributes)
        }
    }
}
