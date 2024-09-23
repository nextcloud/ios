//
//  CommonButtonConstants.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 23.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation
import SwiftUI

enum CommonButtonConstants {
    static let defaultFont: Font = .title2
    static let defaultUIFont: UIFont = .preferredFont(forTextStyle: .title2)
    
    static let defaultBorderWidth: CGFloat = 2.0
    
    static let intrinsicContentSize: CGSize = .init(width: defaultWidth, height: defaultHeight)
    static let defaultHeight: CGFloat = 48
    static var defaultWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 100 : 240
    }
}
