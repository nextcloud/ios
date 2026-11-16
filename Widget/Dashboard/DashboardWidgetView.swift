// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents
import SwiftUI
import WidgetKit

nonisolated enum DashboardWidgetLayout {
    static let padding: CGFloat = 12
    static let sectionSpacing: CGFloat = 4
    static let headerHeight: CGFloat = 22
    static let footerHeight: CGFloat = 44
    static let actionHeight: CGFloat = 36
    static let rowHeight: CGFloat = 44
    static let iconSize: CGFloat = 32
    static let rowSpacing: CGFloat = 10

    static func rowCount(for height: CGFloat, hasActions: Bool) -> Int {
        guard height.isFinite else { return 0 }
        let reservedHeight = 2 * padding + 2 * sectionSpacing + headerHeight + footerHeight
        let actionSpace = hasActions ? actionHeight + sectionSpacing : 0
        let rows = (height - reservedHeight - actionSpace) / rowHeight
        return Int(min(50, max(0, rows)))
    }

    static func visibleActions(_ actions: [DashboardAction],
                               totalRows: Int,
                               height: CGFloat,
                               loadedRows: Int = .max) -> [DashboardAction] {
        let otherActions = actions.filter { !$0.hidesWhenAllRowsFit }
        let rowsWithoutMore = rowCount(for: height, hasActions: !otherActions.isEmpty)
        return totalRows > min(rowsWithoutMore, loadedRows) ? actions : otherActions
    }
}

struct DashboardWidgetView: View {
    let entry: DashboardDataEntry

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let actions = DashboardWidgetLayout.visibleActions(entry.buttons,
                                                               totalRows: entry.totalRows,
                                                               height: height,
                                                               loadedRows: entry.rows.count)
            let rows = entry.rows.prefix(DashboardWidgetLayout.rowCount(for: height, hasActions: !actions.isEmpty))

            VStack(alignment: .leading, spacing: DashboardWidgetLayout.sectionSpacing) {
                header

                if let webURL = entry.webURL, let browserURL = dashboardBrowserDeepLink(for: webURL) {
                    VStack(spacing: 10) {
                        Text(NSLocalizedString("_widget_dashboard_available_on_web_", value: "Available on the web", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Link(destination: browserURL) {
                            Label(NSLocalizedString("_widget_dashboard_open_in_browser_", value: "Open in browser", comment: ""), systemImage: "safari")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if entry.totalRows == 0, !entry.isPlaceholder {
                    Text(NSLocalizedString("_no_data_available_", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            dashboardRow(row)
                                .overlay(alignment: .bottomLeading) {
                                    if row.id != rows.last?.id {
                                        Divider()
                                            .padding(.leading, DashboardWidgetLayout.iconSize + DashboardWidgetLayout.rowSpacing)
                                    }
                                }
                        }
                    }
                    .redacted(reason: entry.isPlaceholder ? .placeholder : [])
                    .frame(maxHeight: .infinity, alignment: .top)
                }

                if !actions.isEmpty {
                    actionRow(actions)
                }

                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DashboardWidgetLayout.padding)
        }
        .containerBackground(.background, for: .widget)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(uiImage: entry.titleImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text(entry.title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(height: DashboardWidgetLayout.headerHeight)
    }

    private func actionRow(_ actions: [DashboardAction]) -> some View {
        HStack(spacing: 8) {
            ForEach(actions) { action in
                Link(destination: action.url) {
                    Text(action.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .frame(height: DashboardWidgetLayout.actionHeight)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if entry.allowsRefresh {
                Button(intent: RefreshDashboardWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: DashboardWidgetLayout.footerHeight, height: DashboardWidgetLayout.footerHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(NSLocalizedString("_widget_refresh_dashboard_", value: "Refresh Dashboard", comment: "")))
            }

            VStack(alignment: .leading, spacing: 2) {
                Label(entry.footerText, systemImage: entry.footerImage)
                    .truncationMode(.middle)

                if !entry.isPlaceholder, entry.webURL == nil {
                    let updated = entry.date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
                    Text(String.localizedStringWithFormat(
                        NSLocalizedString("_widget_updated_at_", value: "Updated %@", comment: ""),
                        updated
                    ))
                    .invalidatableContent()
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: DashboardWidgetLayout.footerHeight)
    }

    @ViewBuilder
    private func dashboardRow(_ row: DashboardData) -> some View {
        if let link = row.link {
            Link(destination: link) {
                rowContent(row)
            }
        } else {
            rowContent(row)
        }
    }

    private func rowContent(_ row: DashboardData) -> some View {
        HStack(spacing: DashboardWidgetLayout.rowSpacing) {
            rowIcon(row)
                .frame(width: DashboardWidgetLayout.iconSize, height: DashboardWidgetLayout.iconSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !row.subtitle.isEmpty {
                    Text(row.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: DashboardWidgetLayout.rowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func rowIcon(_ row: DashboardData) -> some View {
        if let color = row.calendarColor {
            Circle()
                .fill(Color(color))
                .frame(width: 12, height: 12)
        } else if let icon = row.icon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
                .frame(width: DashboardWidgetLayout.iconSize, height: DashboardWidgetLayout.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: row.isRound ? DashboardWidgetLayout.iconSize / 2 : 6))
        } else {
            Image(systemName: "doc")
                .font(.system(size: 19))
                .foregroundStyle(.secondary)
        }
    }
}

struct DashboardWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sample = dashboardSampleEntry(height: 360)
        let entry = DashboardDataEntry(date: Date(),
                                       rows: sample.rows,
                                       totalRows: sample.totalRows,
                                       buttons: [],
                                       webURL: nil,
                                       isPlaceholder: false,
                                       allowsRefresh: true,
                                       titleImage: sample.titleImage,
                                       title: sample.title,
                                       footerImage: sample.footerImage,
                                       footerText: sample.footerText)

        DashboardWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
