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
    static var defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
}

struct TitlePreferenceKey: PreferenceKey {
    static var defaultValue: String = ""

    static func reduce(value: inout String, nextValue: () -> String) {}
}
