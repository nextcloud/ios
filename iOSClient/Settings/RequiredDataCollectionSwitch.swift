//
//  RequiredDataCollectionSwitch.swift
//  Nextcloud
//
//  Created by A200073704 on 25/04/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import UIKit


class RequiredDataCollectionSwitch: XLFormBaseCell {
                
        @IBOutlet weak var cellLabel: UILabel!
        @IBOutlet weak var requiredDataCollectionSwitchControl: UISwitch!
        
        override func awakeFromNib() {
            super.awakeFromNib()
            // Initialization code
            //requiredDataCollectionSwitchControl.addTarget(self, action: #selector(switchChanged), for: UIControl.Event.valueChanged)
            
        }
        
        override func configure() {
            super.configure()
            
            requiredDataCollectionSwitchControl.isOn = true
            requiredDataCollectionSwitchControl.isEnabled = false
        }
        
        override func update() {
            super.update()
        }
}
