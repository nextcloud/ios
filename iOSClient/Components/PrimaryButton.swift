//
//  PrimaryButton.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 20.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit

class PrimaryButton: UIButton {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = UIColor(resource: .Button.Primary.Background.normal)
        setTitleColor(UIColor(resource: .Button.Primary.Text.normal), for: .normal)
        setTitleColor(UIColor(resource: .Button.Primary.Text.selected), for: .selected)
        setTitleColor(UIColor(resource: .Button.Primary.Text.disabled), for: .disabled)
        layer.cornerRadius = bounds.height/2.0
        layer.masksToBounds = true
        titleLabel?.font = .systemFont(ofSize: 14.0)
    }
    
    override public var isEnabled: Bool {
        didSet {
            if self.isEnabled {
                self.backgroundColor = UIColor(resource: .Button.Primary.Background.normal)
            } else {
                self.backgroundColor = UIColor(resource: .Button.Primary.Background.disabled)
            }
        }
    }
    
    override open var isHighlighted: Bool {
        didSet {
            super.isHighlighted = isHighlighted
            
            if !isEnabled {
                backgroundColor = UIColor(resource: .Button.Primary.Background.disabled)
                return
            }
            
            backgroundColor = isHighlighted ? UIColor(resource: .Button.Primary.Background.selected) : UIColor(resource: .Button.Primary.Background.normal)
        }
    }
    
    
}

