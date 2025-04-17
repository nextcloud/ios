//
//  LinkButton.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 26.09.2024.
//  Copyright © 2024 STRATO GmbH
//

import UIKit

class LinkButton: UIButton {
    override func awakeFromNib() {
        super.awakeFromNib()
        
        titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        backgroundColor = .clear
        updateApperance()
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
    
    private func updateApperance() {
        setTitleColor(titleColor(), for: .normal)
    }
    
    private func titleColor() -> UIColor {
        guard isEnabled else {
            return UIColor(resource: .Button.Link.Text.disabled)
        }
        if isHighlighted {
            return UIColor(resource: .Button.Link.Text.selected)
        }
        return UIColor(resource: .Button.Link.Text.normal)
    }
    
}
