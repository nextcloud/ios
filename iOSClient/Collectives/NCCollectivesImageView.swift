// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// An embedded image at full content width; tapping opens it in Quick Look.
struct NCCollectivesImageView: View {
    let embed: NCCollectivesEmbed
    let account: String
    let isOpening: Bool
    let open: () -> Void

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        if failed {
            NCCollectivesAttachmentRow(embed: embed, isOpening: isOpening, open: open)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: open) {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(embed.caption ?? embed.name))
                .accessibilityAddTraits(.isImage)
                if let caption = embed.caption {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .task(id: embed) {
                image = NCCollectivesFileLoader.shared.cachedImage(for: embed, account: account)
                guard image == nil else { return }
                image = await NCCollectivesFileLoader.shared.image(for: embed, account: account)
                failed = image == nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                // Keep small images at their natural size instead of blowing them up.
                .frame(maxWidth: image.size.width, alignment: .leading)
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
                .overlay {
                    if isOpening {
                        ProgressView()
                            .padding(12)
                            .background(.regularMaterial, in: Circle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            shape
                .fill(Color(.secondarySystemFill))
                .aspectRatio(16 / 10, contentMode: .fit)
                .overlay(ProgressView())
        }
    }
}
