//
//  NextcloudWidget.swift
//  NextcloudWidget
//
//  Created by Marino Faggiana on 20/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {

    typealias Entry = DashboardDataEntry

    func placeholder(in context: Context) -> Entry {
        return Entry(date: Date(), dashboardDatas: [], isPlaceholder: true, title: getTitle(account: nil), items: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        readDashboard { dashboardDatas, isPlaceholder, title, items in
            completion(Entry(date: Date(), dashboardDatas: dashboardDatas, isPlaceholder: isPlaceholder, title: title, items: items))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        readDashboard { dashboardDatas, isPlaceholder, title, items in
            let timeLine = Timeline(entries: [Entry(date: Date(), dashboardDatas: dashboardDatas, isPlaceholder: isPlaceholder, title: title, items: items)], policy: .atEnd)
            completion(timeLine)
        }
    }
}

@main
struct DashboardWidget: Widget {
    let kind: String = "NextcloudWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Nextcloud Dashboard")
        .description(NSLocalizedString("_subtitle_dashboard_", comment: ""))
    }
}

struct DashboardWidget_Previews: PreviewProvider {

    static var previews: some View {
        let entry = DashboardDataEntry(date: Date(), dashboardDatas: dashboardDatasTest, isPlaceholder: false, title: getTitle(account: nil), items: 0)
        DashboardWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
