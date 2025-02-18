//
//  AssistantLabelStyle.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 18.02.25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct CustomLabelStyle: LabelStyle {
    var spacing: Double = 5

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}
