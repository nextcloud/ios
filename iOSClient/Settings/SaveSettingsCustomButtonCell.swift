//
//  SaveSettingsCustomButtonCell.swift
//  Nextcloud
//
//  Created by A200073704 on 25/04/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import UIKit


class SaveSettingsCustomButtonCell: XLFormButtonCell {
                
    @IBOutlet weak var saveSettingsButton: UIButton!
    
        override func awakeFromNib() {
            super.awakeFromNib()
            // Initialization code
            self.selectionStyle = .none
            self.separatorInset = UIEdgeInsets(top: 0, left: .greatestFiniteMagnitude, bottom: 0, right: .greatestFiniteMagnitude)
            saveSettingsButton.setTitle(NSLocalizedString("_save_settings_", comment: ""), for: .normal)
            saveSettingsButton.addTarget(self, action: #selector(saveButtonClicked), for: .touchUpInside)

        }
        
        override func configure() {
            super.configure()
            saveSettingsButton.backgroundColor = NCBrandColor.shared.brand
            saveSettingsButton.tintColor = UIColor.white
            saveSettingsButton.layer.cornerRadius = 5
            saveSettingsButton.layer.borderWidth = 1
            saveSettingsButton.layer.borderColor = NCBrandColor.shared.brand.cgColor

        }
        
        override func update() {
            super.update()
            
        }
    
    @objc func saveButtonClicked(sender: UIButton) {
        self.rowDescriptor.value = sender
    
    }
  
}
