// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UniformTypeIdentifiers

/// A file card with type icon, name and size; tapping opens it in Quick Look.
struct NCCollectivesAttachmentRow: View {
    let embed: NCCollectivesEmbed
    let isOpening: Bool
    let open: () -> Void

    private var systemImage: String {
        guard let type = embed.contentType else { return "doc" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return "film" }
        if type.conforms(to: .audio) { return "waveform" }
        if type.conforms(to: .spreadsheet) { return "tablecells" }
        if type.conforms(to: .presentation) { return "rectangle.on.rectangle" }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }

    private var subtitle: String? {
        let size = embed.attachment.map { ByteCountFormatter.string(fromByteCount: $0.filesize, countStyle: .file) }
        let type = embed.contentType?.localizedDescription
        let parts = [type, size].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                NCCollectivesEmojiIcon(emoji: nil, systemImage: systemImage, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(embed.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if isOpening {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isOpening)
    }
}
