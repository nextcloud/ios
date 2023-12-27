//
//  PreferenceKeys.swift
//  Nextcloud
//
//  Created by Milen on 15.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {}
}

struct ScrollIsOnTopPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = true

    static func reduce(value: inout Bool, nextValue: () -> Bool) {}
}

struct ScrollIsOnBottomPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = true

    static func reduce(value: inout Bool, nextValue: () -> Bool) {}
}

struct TitlePreferenceKey: PreferenceKey {
    static var defaultValue: String = ""

    static func reduce(value: inout String, nextValue: () -> String) {}
}
