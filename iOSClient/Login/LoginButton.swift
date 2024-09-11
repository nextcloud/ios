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
		setTitleColor(UIColor(named: "Launch/LoginButtonTextNormal"), for: .normal)
		setTitleColor(UIColor(named: "Launch/LoginButtonTextNormal"), for: .selected)
		setTitleColor(UIColor(named: "Launch/LoginButtonTextDisabled"), for: .disabled)
	}
	
	override public var isEnabled: Bool {
		didSet {
			if self.isEnabled {
				self.backgroundColor = UIColor(named: "Launch/LoginButtonBackgroundNormal")
			} else {
				self.backgroundColor = UIColor(named: "Launch/LoginButtonBackgroundDisabled")
			}
		}
	}
	
	override open var isHighlighted: Bool {
		didSet {
			super.isHighlighted = isHighlighted
			backgroundColor = isHighlighted ? UIColor(named: "Launch/LoginButtonBackgroundSelected") : UIColor(named: "Launch/LoginButtonBackgroundNormal")
		}
	}
	
	
}
