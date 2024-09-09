//
//  CopyMoveDialogButton.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 06.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit

class CopyMoveDialogButton: UIButton {

	override open var isHighlighted: Bool {
		didSet {
			super.isHighlighted = isHighlighted
			backgroundColor = isHighlighted ? UIColor(named: "CopyMove/ButtonStateSelected") : UIColor(named: "CopyMove/ButtonStateNormal")
		}
	}
}
