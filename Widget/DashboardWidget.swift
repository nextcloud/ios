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

    typealias Entry = DashboardListEntry

    func placeholder(in context: Context) -> Entry {
        return Entry(date: Date(), dashboardDatas: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        readDashboard { dashboardDatas in
            completion(Entry(date: Date(), dashboardDatas: dashboardDatas))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        readDashboard { dashboardDatas in
            let timeLine = Timeline(entries: [Entry(date: Date(), dashboardDatas: dashboardDatas)], policy: .atEnd)
            completion(timeLine)
        }
    }
}

@main
struct DashboardWidget: Widget {
    let kind: String = "DashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ListWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Nextcloud Dashboard")
        .description(NSLocalizedString("_subtitle_dashboard_", comment: ""))
    }
}

struct DashboardWidget_Previews: PreviewProvider {

    static var previews: some View {
        let entry = DashboardListEntry(date: Date(), dashboardDatas: dashboardDatasTest)
        ListWidgetEntryView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
