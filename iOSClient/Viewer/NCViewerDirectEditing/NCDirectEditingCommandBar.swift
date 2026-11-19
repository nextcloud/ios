// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCDirectEditingCommandBar: View {
    static let height: CGFloat = 48
    private static let maximumFileNameWidth: CGFloat = 220

    @Environment(\.colorScheme) private var colorScheme

    var fileName: String
    var isFavorite: Bool
    var isUpdatingFavorite = false
    let onBack: () -> Void
    let onDetails: () -> Void
    let onToggleFavorite: () -> Void

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
            Button(action: onBack) {
                Image(systemName: "chevron.backward.circle")
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(NSLocalizedString("_back_", comment: "")))
            commandDivider
            FileNameLayout(maximumWidth: Self.maximumFileNameWidth) {
                Text(verbatim: fileName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 12)
            commandDivider
            Spacer(minLength: 0)
            commandDivider
            Button(action: onToggleFavorite) {
                HStack(spacing: 6) {
                    Image(systemName: isFavorite ? "star.slash.fill" : "star.fill")
                        .environment(\.symbolVariants, .none)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color(uiColor: NCBrandColor.shared.yellowFavorite))
                        .accessibilityHidden(true)
                    Text(NSLocalizedString(isFavorite ? "_remove_favorites_" : "_add_favorites_", comment: ""))
                }
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isUpdatingFavorite)
            .layoutPriority(1)
            commandDivider
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
            .layoutPriority(1)
        }
        .frame(height: Self.height)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 6)
    }

    private var commandDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 20)
            .accessibilityHidden(true)
    }

    private struct FileNameLayout: Layout {
        let maximumWidth: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            guard let text = subviews.first else { return .zero }
            let idealWidth = text.sizeThatFits(.unspecified).width
            let width = min(idealWidth, maximumWidth, proposal.width ?? maximumWidth)
            let height = text.sizeThatFits(ProposedViewSize(width: width, height: proposal.height)).height
            return CGSize(width: width, height: height)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
        }
    }

    private var foldDecoration: some View {
        let isDark = colorScheme == .dark

        return LinearGradient(
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
        .frame(height: 16)
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
