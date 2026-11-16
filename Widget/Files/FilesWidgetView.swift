// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents
import SwiftUI
import WidgetKit

nonisolated enum FilesWidgetLayout {
    static let padding: CGFloat = 12
    static let sectionSpacing: CGFloat = 4
    static let headerHeight: CGFloat = 22
    static let footerHeight: CGFloat = 44
    static let rowHeight: CGFloat = 44
    static let thumbnailSize: CGFloat = 32
    static let rowSpacing: CGFloat = 10

    static func rowCount(for height: CGFloat) -> Int {
        guard height.isFinite else { return 0 }
        let reservedHeight = 2 * padding + 2 * sectionSpacing + headerHeight + footerHeight
        // The WebDAV search returns at most 50 results.
        let rows = (height - reservedHeight) / rowHeight
        return Int(min(50, max(0, rows)))
    }
}

struct FilesWidgetView: View {
    let entry: FilesDataEntry

    var body: some View {
        GeometryReader { geometry in
            let files = entry.datas.prefix(FilesWidgetLayout.rowCount(for: geometry.size.height))

            VStack(alignment: .leading, spacing: FilesWidgetLayout.sectionSpacing) {
                Text(NSLocalizedString("_widget_recent_files_", value: "Recent files", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .frame(height: FilesWidgetLayout.headerHeight)
                    .accessibilityAddTraits(.isHeader)

                if entry.isEmpty {
                    Label {
                        Text(NSLocalizedString("_widget_no_recent_files_", value: "No recent files", comment: ""))
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(files) { file in
                            fileRow(file)
                                .overlay(alignment: .bottomLeading) {
                                    if file.id != files.last?.id {
                                        Divider()
                                            .padding(.leading, FilesWidgetLayout.thumbnailSize + FilesWidgetLayout.rowSpacing)
                                    }
                                }
                        }
                    }
                    .redacted(reason: entry.isPlaceholder ? .placeholder : [])
                    .frame(maxHeight: .infinity, alignment: .top)
                }

                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(FilesWidgetLayout.padding)
        }
        .containerBackground(.background, for: .widget)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if entry.allowsRefresh {
                Button(intent: RefreshFilesWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: FilesWidgetLayout.footerHeight, height: FilesWidgetLayout.footerHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(NSLocalizedString("_widget_refresh_files_", value: "Refresh recent files", comment: "")))
            }

            VStack(alignment: .leading, spacing: 2) {
                Label(entry.footerText, systemImage: entry.footerImage)
                    .truncationMode(.middle)

                if !entry.isPlaceholder {
                    let updated = entry.date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
                    Text(String.localizedStringWithFormat(
                        NSLocalizedString("_widget_files_updated_at_", value: "Updated %@", comment: ""),
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
        .frame(height: FilesWidgetLayout.footerHeight)
    }

    @ViewBuilder
    private func fileRow(_ file: FilesData) -> some View {
        if let url = file.url {
            Link(destination: url) {
                rowContent(file)
            }
        } else {
            rowContent(file)
        }
    }

    private func rowContent(_ file: FilesData) -> some View {
        HStack(spacing: FilesWidgetLayout.rowSpacing) {
            thumbnail(file)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                FilesWidgetBidiFilename(filename: file.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(file.subTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: FilesWidgetLayout.rowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func thumbnail(_ file: FilesData) -> some View {
        Image(uiImage: file.image)
            .renderingMode(file.useTypeIconFile ? .template : .original)
            .resizable()
            .aspectRatio(contentMode: file.useTypeIconFile ? .fit : .fill)
            .foregroundStyle(.secondary)
            .frame(width: FilesWidgetLayout.thumbnailSize, height: FilesWidgetLayout.thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct FilesWidgetBidiFilename: View {
    let filename: String

    var body: some View {
        let name = filename as NSString
        let ext = name.pathExtension
        let base = name.deletingPathExtension

        if ext.isEmpty || base.isEmpty {
            Text(filename)
                .truncationMode(.middle)
        } else {
            HStack(spacing: 0) {
                Text(base)
                    .truncationMode(.middle)
                Text("." + ext)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .accessibilityLabel(Text(filename))
        }
    }
}

struct FilesWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = FilesDataEntry(
            date: Date(),
            datas: filesWidgetSampleRows(count: 8),
            isPlaceholder: false,
            isEmpty: false,
            allowsRefresh: true,
            footerImage: "checkmark.icloud",
            footerText: "Nextcloud (Personal)"
        )
        FilesWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
