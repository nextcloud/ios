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
    @State private var autoUploadCounter = NCAutoUploadCounter()
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
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    if let appsSection = model.sections.first(where: { $0.type == .moreApps }) {
                        moreAppsSection(items: appsSection.items)
                    }

                    autoUploadSection

                    ForEach(model.sections.filter { $0.type == .regular }) { section in
                        menuSection(items: section.items)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Color(.systemGroupedBackground).opacity(0),
                                        Color(.systemGroupedBackground)],
                               startPoint: .top,
                               endPoint: .bottom)
                    .frame(height: 32)
                    .allowsHitTesting(false)
            }

            quotaSection
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            guard loadItemsOnAppear else { return }
            await model.loadItems()
        }
        .onAppear {
            updateAutoUploadCounter()
        }
        .onDisappear {
            autoUploadCounter.stop()
        }
        .onChange(of: model.autoUploadStart) {
            updateAutoUploadCounter()
        }
    }

    private func updateAutoUploadCounter() {
        let session = model.session

        autoUploadCounter.start(account: session.account,
                                urlBase: session.urlBase,
                                userId: session.userId,
                                autoUploadStart: model.autoUploadStart)
    }

    private var autoUploadSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                model.openAutoUpload(counter: autoUploadCounter)
            } label: {
                HStack(spacing: 16) {
                    NCFocusedAutoUploadCloudAnimation(size: 44,
                                                      cloudColor: Color(NCBrandColor.shared.iconImageColor),
                                                      arrowColor: model.autoUploadStart
                                                      ? Color(UIColor.systemBackground)
                                                      : Color(NCBrandColor.shared.iconImageColor),
                                                      isAnimated: model.autoUploadStart)
                        .frame(width: 39)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("_settings_autoupload_", comment: ""))
                            .font(.body)
                            .foregroundColor(Color(NCBrandColor.shared.textColor))

                        if model.autoUploadStart && autoUploadCounter.isLoaded {
                            Text(autoUploadCounter.itemsLeftSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(NSLocalizedString("_autoupload_description_", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        }
    }

    private func moreAppsSection(items: [NCMoreModel.Item]) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.element.identifier) { _, item in
                shortcutButton(item)
            }
        }
    }

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
            model.perform(item.destination)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: item.image)
                    .font(.icon())
                    .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                    .frame(width: 39)

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
            .padding(.leading, 71)
    }

    @ViewBuilder
    private var quotaSection: some View {
        if !model.quotaDescription.isEmpty || !model.quotaExternalSiteTitle.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !model.quotaDescription.isEmpty {
                    Text(model.quotaDescription)
                        .font(.footnote)
                        .foregroundColor(.primary)
                        .lineLimit(2)

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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
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

                if model.quotaProgress >= 1 {
                    Capsule()
                        .fill(Color.red)
                        .frame(width: width)
                } else {
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
        }
        .frame(height: 4)
    }
}

// MARK: - Preview

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

#Preview {
    NCMoreView(model: .preview)
}
