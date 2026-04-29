// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct NCMoreView: View {
    @StateObject private var model: NCMoreModel

    private weak var controller: NCMainTabBarController?

    init(account: String, controller: NCMainTabBarController?) {
        _model = StateObject(wrappedValue: NCMoreModel(account: account))
        self.controller = controller
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
            await model.loadItems()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(model.sections) { section in
                    switch section.type {
                    case .moreApps:
                        moreAppsSection

                    case .regular:
                        menuSection(items: section.items)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
    }

    private var moreAppsSection: some View {
        HStack(spacing: 14) {
            shortcutButton(
                title: "Talk",
                systemImage: "magnifyingglass",
                action: .moreApps
            )

            shortcutButton(
                title: "Notes",
                systemImage: "pencil",
                action: .moreApps
            )

            shortcutButton(
                title: NSLocalizedString("_more_apps_", comment: ""),
                systemImage: "square.grid.2x2.fill",
                action: .moreApps
            )
        }
    }

    private func shortcutButton(
        title: String,
        systemImage: String,
        action: NCMoreModel.Action
    ) -> some View {
        Button {
            Task { @MainActor in
                action.perform(controller: controller)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 94)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

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

    private func menuRow(_ item: NCMoreModel.Item) -> some View {
        Button {
            Task { @MainActor in
                item.action.perform(controller: controller)
            }
        } label: {
            HStack(spacing: 22) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                    .frame(width: 34)

                Text(NSLocalizedString(item.titleKey, comment: ""))
                    .font(.body)
                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 18)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.45))
            .frame(height: 0.5)
            .padding(.leading, 74)
    }

    private var quotaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.quotaDescription.isEmpty {
                Text(model.quotaDescription)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                ProgressView(value: model.quotaProgress)
                    .progressViewStyle(.linear)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.account)))
            }

            if !model.quotaExternalSiteTitle.isEmpty,
               let url = model.quotaExternalSiteUrl {
                Button {
                    Task { @MainActor in
                        NCMoreModel.Action.browser(
                            url: url,
                            title: model.quotaExternalSiteTitle
                        ).perform(controller: controller)
                    }
                } label: {
                    Text(model.quotaExternalSiteTitle)
                        .font(.footnote)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(Color(.systemGroupedBackground))
    }
}
