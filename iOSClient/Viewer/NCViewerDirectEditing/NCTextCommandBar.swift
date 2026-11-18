// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCTextCommandBar: View {
    static let height: CGFloat = 48

    let onDetails: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            commands
            foldDecoration
                .frame(maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var commands: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Divider()
                .frame(height: 24)
            Button(action: onDetails) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .accessibilityHidden(true)
                    Text(NSLocalizedString("_details_", comment: ""))
                }
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: Self.height)
        .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 16))
    }

    private var foldDecoration: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.55), location: 0.35),
                .init(color: .black.opacity(0.32), location: 0.52),
                .init(color: .black.opacity(0.14), location: 0.72),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 8)
    }
}
