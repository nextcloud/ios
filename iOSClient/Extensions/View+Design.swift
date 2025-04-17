//
//  View+Design.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 06.01.2025.
//  Copyright © 2025 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

extension View {
    func applyScrollContentBackground() -> some View {
        self.modifier(ScrollContentBackgroundModifier())
    }
    
    func applyGlobalFormStyle() -> some View {
        self
            .applyScrollContentBackground()
            .background(Color(NCBrandColor.shared.formBackgroundColor))
    }
    
    func applyGlobalFormSectionStyle() -> some View {
        self
            .listRowBackground(Color(NCBrandColor.shared.formRowBackgroundColor))
            .listRowSeparatorTint(Color(NCBrandColor.shared.formSeparatorColor))
    }
}

struct ScrollContentBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}
