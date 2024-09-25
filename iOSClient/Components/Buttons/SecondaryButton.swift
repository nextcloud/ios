//
//  SecondaryButton.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 23.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit

class SecondaryButton: UIButton {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = UIColor(resource: .Button.Secondary.Background.normal)
        
        setTitleColor(UIColor(resource: .Button.Secondary.Text.normal), for: .normal)
        setTitleColor(UIColor(resource: .Button.Secondary.Text.selected), for: .selected)
        setTitleColor(UIColor(resource: .Button.Secondary.Text.disabled), for: .disabled)
        
        layer.masksToBounds = true
        layer.borderWidth = CommonButtonConstants.defaultBorderWidth
        layer.borderColor = borderColor()
        
        titleLabel?.font = CommonButtonConstants.defaultUIFont
    }
    
    override var intrinsicContentSize: CGSize {
        return CommonButtonConstants.intrinsicContentSize
    }
    
    override public var isEnabled: Bool {
        didSet {
            if self.isEnabled {
                self.backgroundColor = UIColor(resource: .Button.Secondary.Background.normal)
            } else {
                self.backgroundColor = UIColor(resource: .Button.Secondary.Background.disabled)
            }
        }
    }
    
    override open var isHighlighted: Bool {
        didSet {
            super.isHighlighted = isHighlighted
            
            if !isEnabled {
                backgroundColor = UIColor(resource: .Button.Secondary.Background.disabled)
                return
            }
            
            backgroundColor = isHighlighted ? UIColor(resource: .Button.Secondary.Background.selected) : UIColor(resource: .Button.Secondary.Background.normal)
        }
    }
    
    override func layoutSubviews() {
        layer.cornerRadius = bounds.height/2.0
        super.layoutSubviews()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            layer.borderColor = borderColor()
        }
    }
    
    private func borderColor() -> CGColor {
        return UIColor(resource: isEnabled ? .Button.Secondary.Border.normal : .Button.Secondary.Border.disabled).cgColor
    }
}
