// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import WidgetKit

struct LockscreenWidgetView: View {
    let entry: LockscreenData
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            if entry.error {
                Gauge(
                    value: 0,
                    label: {},
                    currentValueLabel: {
                        Image(systemName: "xmark.icloud")
                            .font(.system(size: 25.0).weight(.light))
                    }
                )
                .gaugeStyle(.accessoryCircularCapacity)
                .containerBackground(.clear, for: .widget)
            } else {
                Gauge(
                    value: entry.quotaRelative,
                    label: {
                        Text(" " + entry.quotaTotal + " ")
                            .font(.system(size: 8.0))
                    },
                    currentValueLabel: {
                        Text(entry.quotaUsed)
                    }
                )
                .gaugeStyle(.accessoryCircular)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])
                .containerBackground(.clear, for: .widget)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 1) {
                    Image(systemName: "bolt.fill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 11, height: 11)
                    Text(NSLocalizedString("_recent_activity_", comment: ""))
                        .font(.system(size: 11))
                        .fontWeight(.heavy)
                }
                if entry.error {
                    VStack(spacing: 1) {
                        Image(systemName: "xmark.icloud")
                            .font(Font.system(size: 25.0).weight(.light))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }.padding(8)
                } else {
                    Text(entry.activity)
                        .font(.system(size: 12)).bold()
                }
            }
            .widgetURL(entry.link)
            .redacted(reason: entry.isPlaceholder ? .placeholder : [])
            .containerBackground(.clear, for: .widget)
        default:
            Text("Not implemented")
        }
    }
}

struct LockscreenWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        let entry = LockscreenData(date: Date(), isPlaceholder: false, activity: "Alba Mayoral changed Marketing / Regional Marketing / Agenda Meetings / Q4 2022 / OCTOBER / 13.11 Afrah Kahlid.md", link: URL(string: "https://")!, quotaRelative: 0.5, quotaUsed: "999 GB", quotaTotal: "999 GB", error: false)
        LockscreenWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .accessoryRectangular)).previewDisplayName("Rectangular")
        LockscreenWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .accessoryCircular)).previewDisplayName("Circular")
    }
}
