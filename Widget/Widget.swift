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

@main
struct NextcloudWidgetBundle: WidgetBundle {

    @WidgetBundleBuilder
    var body: some Widget {
        ToolbarWidget()
        NextcloudWidget()
        DashboardWidget()
    }
}

struct DashboardWidget: Widget {
    let kind: String = "DashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardWidgetProvider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Dashboard")
        .description(NSLocalizedString("_description_dashboardwidget_", comment: ""))
    }
}

struct NextcloudWidget: Widget {
    let kind: String = "NextcloudWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextcloudWidgetProvider()) { entry in
            NextcloudWidgetView(entry: entry)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName(NCBrandOptions.shared.brand)
        .description(NSLocalizedString("_description_nextcloudwidget_", comment: ""))
    }
}

struct ToolbarWidget: Widget {
    let kind: String = "ToolbarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ToolbarWidgetProvider()) { entry in
            ToolbarWidgetView(entry: entry)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Toolbar")
        .description(NSLocalizedString("_description_toolbarwidget_", comment: ""))
    }
}
