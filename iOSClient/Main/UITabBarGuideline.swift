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
	static let defaultTabItemsCount = 4
	
	static func padItemsSpacing(for viewWidth: CGFloat, itemsCount: Int = defaultTabItemsCount) -> CGFloat {
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
						
			setTabBarItemColors(tabBarAppearance.stackedLayoutAppearance)
			setTabBarItemColors(tabBarAppearance.inlineLayoutAppearance)
			setTabBarItemColors(tabBarAppearance.compactInlineLayoutAppearance)

			let stackedLayoutOffset = UITabBarGuideline.tabbarItemTitleStackedLayoutOffset
			tabBarAppearance.stackedLayoutAppearance.selected.titlePositionAdjustment = stackedLayoutOffset
			tabBarAppearance.stackedLayoutAppearance.normal.titlePositionAdjustment = stackedLayoutOffset

			let compactInlineLayoutOffset = UITabBarGuideline.tabbarItemTitleCompactInlineLayoutOffset
			tabBarAppearance.compactInlineLayoutAppearance.selected.titlePositionAdjustment = compactInlineLayoutOffset
			tabBarAppearance.compactInlineLayoutAppearance.normal.titlePositionAdjustment = compactInlineLayoutOffset
			
			if UIDevice.current.userInterfaceIdiom == .pad {
				tabBarAppearance.stackedItemPositioning = .centered
				if let windowWidth = UIDevice.current.mainWindow?.bounds.width {
					tabBarAppearance.stackedItemSpacing = UITabBarGuideline.padItemsSpacing(for: windowWidth)
				}
			}
			
			let appearance = NCMainTabBar.appearance()
			appearance.standardAppearance = tabBarAppearance
			appearance.scrollEdgeAppearance = tabBarAppearance
		}
	}
	
	private static func setTabBarItemColors(_ itemAppearance: UITabBarItemAppearance) {
		let normalColor = UIColor(resource: .Tabbar.inactiveItem)
		let selectedColor = UIColor(resource: .Tabbar.activeItem)
		
		itemAppearance.normal.iconColor = normalColor
		itemAppearance.normal.titleTextAttributes = [NSAttributedString.Key.foregroundColor: normalColor]
   
		itemAppearance.selected.iconColor = selectedColor
		itemAppearance.selected.titleTextAttributes = [NSAttributedString.Key.foregroundColor: selectedColor]
	}
}

extension UIDevice {
	var mainWindow: UIWindow? {
		let scenes = UIApplication.shared.connectedScenes
		let windowScene = scenes.first as? UIWindowScene
		return windowScene?.windows.first
	}
	
	var hasComplexSaveArea: Bool {
		guard let window = mainWindow else { return false }
		return (window.safeAreaInsets.top + window.safeAreaInsets.left) > 20
	}
}
