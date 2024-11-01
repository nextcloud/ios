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
	
	static var tabbarItemTitleStackedLayoutOffset: UIOffset {
		UIDevice.current.hasComplexSaveArea ? .zero : UIOffset(horizontal: 0, vertical: -8)
	}
	
	static var tabbarItemTitleCompactInlineLayoutOffset: UIOffset {
		UIDevice.current.hasComplexSaveArea ? .zero : UIOffset(horizontal: 0, vertical: -14)
	}
}

extension NCMainTabBar {
	static func setupAppearance() {
		if !UIDevice.current.hasComplexSaveArea {
			let tabBarAppearance = UITabBarAppearance()
			tabBarAppearance.configureWithOpaqueBackground()
			NCMainTabBar.appearance().standardAppearance = tabBarAppearance
			NCMainTabBar.appearance().scrollEdgeAppearance = tabBarAppearance
			
			let stackedLayoutOffset = UITabBarGuideline.tabbarItemTitleStackedLayoutOffset
			tabBarAppearance.stackedLayoutAppearance.selected.titlePositionAdjustment = stackedLayoutOffset
			tabBarAppearance.stackedLayoutAppearance.normal.titlePositionAdjustment = stackedLayoutOffset

			let compactInlineLayoutOffset = UITabBarGuideline.tabbarItemTitleCompactInlineLayoutOffset
			tabBarAppearance.compactInlineLayoutAppearance.selected.titlePositionAdjustment = compactInlineLayoutOffset
			tabBarAppearance.compactInlineLayoutAppearance.normal.titlePositionAdjustment = compactInlineLayoutOffset
		}
	}
}

extension UIDevice {
	var hasComplexSaveArea: Bool {
		let scenes = UIApplication.shared.connectedScenes
		let windowScene = scenes.first as? UIWindowScene
		guard let window = windowScene?.windows.first else { return false }
		
		return (window.safeAreaInsets.top + window.safeAreaInsets.left) > 20
	}
}
