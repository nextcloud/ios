//
//  AppScreenConstants.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 09.09.2024.
//  Copyright © 2024 STRATO GmbH
//

import Foundation

class AppScreenConstants {
	static let compactMaxSize: CGFloat = 460
	
	static var toolbarHeight: CGFloat {
		UIScreen.main.bounds.size.width > compactMaxSize ? 60.0 : 80.0
	}
}
