//
//  DashboardWidget.swift
//  DashboardWidget
//
//  Created by Marino Faggiana on 20/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

@main
struct DashboardWidget: Widget {
    let kind: String = "DashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { _ in
            DashBoardList(data: dataDashboardPreview)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Nextcloud Dashboard Widget")
        .description("Nextcloud Dashboard Widget.")
    }
}

struct DashboardWidget_Previews: PreviewProvider {

    static var previews: some View {
        DashBoardList(data: dataDashboardPreview).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
