//
//  LoginButton.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 09.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit

class LoginButton: UIButton {
	
	override open var isHighlighted: Bool {
		didSet {
			super.isHighlighted = isHighlighted
			backgroundColor = isHighlighted ? UIColor(named: "Launch/LoginButtonBackgroundHighlighted") : UIColor(named: "Launch/LoginButtonBackgroundNormal")
		}
	}

}
