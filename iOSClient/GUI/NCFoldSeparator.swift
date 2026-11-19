// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

struct NCFoldSeparator: View {
    static let height: CGFloat = 16

    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    static func makeContentView() -> UIView {
        let view = UIHostingConfiguration { NCFoldSeparator() }.margins(.all, 0).makeContentView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }

    var body: some View {
        let isDark = colorScheme == .dark

        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.08), location: 0.25),
                .init(color: .white.opacity(isDark ? 0.24 : 0.72), location: 0.43),
                .init(color: .white.opacity(isDark ? 0.38 : 0.9), location: 0.47),
                .init(color: .black.opacity(isDark ? 0.65 : 0.45), location: 0.52),
                .init(color: .black.opacity(isDark ? 0.36 : 0.18), location: 0.68),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.035),
                    .init(color: .black, location: 0.965),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
