//
//  UITabBarGuideline.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 15.10.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit

class UITabBarGuideline {
	static let padItemWidth: CGFloat = 100
	
	static func padItemsSpacing(for viewWidth: CGFloat, itemsCount: Int) -> CGFloat {
		let itemsCountFloat = CGFloat(itemsCount)
		return ((viewWidth - UITabBarGuideline.padItemWidth * itemsCountFloat) / (itemsCountFloat + 1)) / 1.5
	}

}
