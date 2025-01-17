//
//  PrimaryButton.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 20.09.2024.
//  Copyright © 2024 STRATO AG
//

import UIKit

class PrimaryButton: UIButton {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        layer.masksToBounds = true
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
    
    private func updateApperance() {
        setTitleColor(titleColor(), for: .normal)
        backgroundColor = backgroundColor()
    }
    
    private func backgroundColor() -> UIColor {
        guard isEnabled else {
            return UIColor(resource: .Button.Primary.Background.disabled)
        }
        if isHighlighted {
            return UIColor(resource: .Button.Primary.Background.selected)
        }
        return UIColor(resource: .Button.Primary.Background.normal)
    }
    
    private func titleColor() -> UIColor {
        guard isEnabled else {
            return UIColor(resource: .Button.Primary.Text.disabled)
        }
        if isHighlighted {
            return UIColor(resource: .Button.Primary.Text.selected)
        }
        return UIColor(resource: .Button.Primary.Text.normal)
    }
}

