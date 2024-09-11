//
//  AppScreenConstants.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 09.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation

class AppScreenConstants {
	static var toolbarHeight: CGFloat {
		UIScreen.main.bounds.size.width > 460 ? 60.0 : 80.0
	}
}
