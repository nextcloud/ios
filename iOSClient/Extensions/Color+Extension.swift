//
//  Color+Extension.swift
//  Nextcloud
//
//  Created by Milen on 27.12.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

extension Color {
    static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}
