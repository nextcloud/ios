//
//  CommonButtonConstants.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 23.09.2024.
//  Copyright © 2024 STRATO AG
//

import Foundation
import SwiftUI

enum CommonButtonConstants {
    static let defaultFont: Font = .system(size: 14, weight: .semibold)
    static let defaultUIFont: UIFont = .systemFont(ofSize: 14, weight: .semibold)
    
    static let defaultBorderWidth: CGFloat = 2.0
    
    static let intrinsicContentSize: CGSize = .init(width: defaultWidth, height: defaultHeight)
    static let defaultHeight: CGFloat = 48
    static var defaultWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 100 : 240
    }
}
