// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The emoji of a collective or page on a rounded tile, with a symbol as fallback.
struct NCCollectivesEmojiIcon: View {
    let emoji: String?
    let systemImage: String
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(.tint.opacity(0.12))
            if let emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: size * 0.55))
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
