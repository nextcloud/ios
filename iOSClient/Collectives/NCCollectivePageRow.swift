// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A page in a list: emoji, title and when it was last edited.
struct NCCollectivePageRow: View {
    let title: String
    let page: NCCollectivePage
    var emoji: String?
    var systemImage = "doc.text"

    var body: some View {
        HStack(spacing: 12) {
            NCCollectivesEmojiIcon(emoji: emoji, systemImage: systemImage, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .lineLimit(2)
                Text(page.modificationDate, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
