//
//  LoginButton.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 09.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit

class LoginButton: UIButton {
	
	override func awakeFromNib() {
		super.awakeFromNib()
		setTitleColor(UIColor(resource: .Button.Primary.Text.normal), for: .normal)
		setTitleColor(UIColor(resource: .Button.Primary.Text.normal), for: .selected)
		setTitleColor(UIColor(resource: .Button.Primary.Text.disabled), for: .disabled)
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
