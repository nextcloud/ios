// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

/// SwiftUI implementation of the More tab content.
///
/// `NCMoreView` renders the sections provided by `NCMoreModel`.
/// Navigation is delegated to the model through `Destination`, because the view is hosted
/// inside the UIKit-based `NCMoreNavigationController`.
struct NCMoreView: View {
    @StateObject private var model: NCMoreModel
    private let loadItemsOnAppear: Bool
    private let shortcutIconColor = Color(red: 0, green: 130 / 255, blue: 201 / 255) // Nextcloud Color

    init(account: String, controller: NCMainTabBarController?) {
        _model = StateObject(
            wrappedValue: NCMoreModel(
                controller: controller
            )
        )
        loadItemsOnAppear = true
    }

    init(model: NCMoreModel) {
        _model = StateObject(wrappedValue: model)
        loadItemsOnAppear = false
    }

    @MainActor
    func perform(_ destination: NCMoreModel.Destination) {
        model.perform(destination)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                content
                quotaSection
            }
        }
        .task {
            guard loadItemsOnAppear else { return }
            await model.loadItems()
        }
    }

    /// Main scrollable content of the More tab.
    private var content: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(model.sections) { section in
                    switch section.type {
                    case .moreApps:
                        moreAppsSection(items: section.items)

                    case .regular:
                        menuSection(items: section.items)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
    }

    /// Renders the app suggestion shortcut section.
    ///
    /// - Parameter items: Shortcut items displayed as cards.
    private func moreAppsSection(items: [NCMoreModel.Item]) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.element.identifier) { _, item in
                shortcutButton(item)
            }
        }
    }

    /// Creates a tappable shortcut nextcloud card.
    ///
    /// - Parameter item: Item containing title, image and destination.
    private func shortcutButton(_ item: NCMoreModel.Item) -> some View {
        Button {
            model.perform(item.destination)
        } label: {
            VStack(spacing: 6) {
                Image(item.image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(shortcutIconColor)

                Text(NSLocalizedString(item.titleKey, comment: ""))
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .tint(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Renders a rounded menu section containing multiple rows.
    ///
    /// - Parameter items: Items displayed in the section.
    private func menuSection(items: [NCMoreModel.Item]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.identifier) { index, item in
                menuRow(item)

                if index < items.count - 1 {
                    divider
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Renders a single menu row.
    ///
    /// - Parameter item: Item containing title, icon and destination.
    private func menuRow(_ item: NCMoreModel.Item) -> some View {
        Button {
            model.perform(item.destination)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: item.image)
                    .font(.icon())
                    .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                    .frame(width: 26)

                Text(NSLocalizedString(item.titleKey, comment: ""))
                    .font(.body)
                    .foregroundColor(Color(NCBrandColor.shared.textColor))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .tint(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.45))
            .frame(height: 0.5)
            .padding(.leading, 58)
    }

    private var quotaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.quotaDescription.isEmpty {
                Text(model.quotaDescription)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .tint(.primary)

                quotaProgressView
            }

            if !model.quotaExternalSiteTitle.isEmpty,
               let url = model.quotaExternalSiteUrl {
                Button {
                    model.perform(
                        .browser(
                            url: url,
                            title: model.quotaExternalSiteTitle
                        )
                    )
                } label: {
                    Text(model.quotaExternalSiteTitle)
                        .font(.footnote)
                        .lineLimit(1)
                        .tint(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color(.systemGroupedBackground))
    }

    private var normalizedQuotaProgress: Double {
        min(max(model.quotaProgress, 0), 1)
    }

    private var quotaProgressView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let progress = normalizedQuotaProgress
            let warningThreshold = 0.90
            let brandColor = Color(NCBrandColor.shared.getElement(account: model.account))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))

                Capsule()
                    .fill(brandColor)
                    .frame(width: width * min(progress, warningThreshold))

                if progress > warningThreshold {
                    Capsule()
                        .fill(Color.red)
                        .frame(width: width * (progress - warningThreshold))
                        .offset(x: width * warningThreshold)
                }
            }
        }
        .frame(height: 4)
    }
}

#if DEBUG
extension NCMoreModel {
    static var preview: NCMoreModel {
        let model = NCMoreModel(controller: nil)

        model.sections = [
            Section(
                type: .moreApps,
                items: [
                    Item(
                        titleKey: "Talk",
                        image: "talk-template",
                        destination: .none
                    ),
                    Item(
                        titleKey: "Notes",
                        image: "notes-template",
                        destination: .none
                    ),
                    Item(
                        titleKey: "More apps",
                        image: "more-apps-template",
                        destination: .none
                    )
                ]
            ),
            Section(
                type: .regular,
                items: [
                    Item(
                        titleKey: "_recent_",
                        image: "clock.arrow.circlepath",
                        destination: .none
                    ),
                    Item(
                        titleKey: "_list_shares_",
                        image: "person.badge.plus",
                        destination: .none
                    ),
                    Item(
                        titleKey: "_manage_file_offline_",
                        image: "icloud.and.arrow.down",
                        destination: .none
                    ),
                    Item(
                        titleKey: "_scanned_images_",
                        image: "doc.text.viewfinder",
                        destination: .none
                    ),
                    Item(
                        titleKey: "_trash_view_",
                        image: "trash",
                        destination: .none
                    )
                ]
            ),
            Section(
                type: .regular,
                items: [
                    Item(
                        titleKey: "_settings_",
                        image: "gear",
                        destination: .none
                    )
                ]
            )
        ]

        model.quotaDescription = "You are using 919,31 GB of Unlimited"
        model.quotaProgress = 0.42

        return model
    }
}
#endif

#Preview {
    NCMoreView(model: .preview)
}
