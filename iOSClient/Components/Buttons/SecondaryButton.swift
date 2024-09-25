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
        
        layer.masksToBounds = true
        layer.borderWidth = CommonButtonConstants.defaultBorderWidth
        
        updateApperance()
        
        titleLabel?.font = CommonButtonConstants.defaultUIFont
    }
    
    override var intrinsicContentSize: CGSize {
        return CommonButtonConstants.intrinsicContentSize
    }
    
    override public var isEnabled: Bool {
        didSet {
            updateApperance()
        }
    }
    
    override open var isHighlighted: Bool {
        didSet {
            updateApperance()
        }
    }
    
    override func layoutSubviews() {
        layer.cornerRadius = bounds.height/2.0
        super.layoutSubviews()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateApperance()
        }
    }
    
    private func updateApperance() {
        setTitleColor(titleColor(), for: .normal)
        backgroundColor = backgroundColor()
        layer.borderColor = borderColor()
    }
    
    private func borderColor() -> CGColor {
        return UIColor(resource: isEnabled ? .Button.Secondary.Border.normal : .Button.Secondary.Border.disabled).cgColor
    }
    
    private func backgroundColor() -> UIColor {
        guard isEnabled else {
            return UIColor(resource: .Button.Secondary.Background.disabled)
        }
        if isHighlighted {
            return UIColor(resource: .Button.Secondary.Background.selected)
        }
        return UIColor(resource: .Button.Secondary.Background.normal)
    }
    
    private func titleColor() -> UIColor {
        guard isEnabled else {
            return UIColor(resource: .Button.Secondary.Text.disabled)
        }
        if isHighlighted {
            return UIColor(resource: .Button.Secondary.Text.selected)
        }
        return UIColor(resource: .Button.Secondary.Text.normal)
    }
}
