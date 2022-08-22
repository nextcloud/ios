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
        completion(Entry(date: Date(), dashboardDatas: dashboardDatasTest))
//        if context.isPreview {
//        } else {
//        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let components = DateComponents(minute: 10)
        let futureDate = Calendar.current.date(byAdding: components, to: Date())!
        let datas = dashboardDatasTest
        let timeLine = Timeline(entries: [Entry(date: Date(), dashboardDatas: datas)], policy: .after(futureDate))
        completion(timeLine)
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
        .description("subtitle.")
    }
}

struct DashboardWidget_Previews: PreviewProvider {

    static var previews: some View {
        let entry = DashboardListEntry(date: Date(), dashboardDatas: dashboardDatasTest)
        ListWidgetEntryView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
