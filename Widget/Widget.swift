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
import Intents
import SwiftUI

@main
struct NextcloudWidgetBundle: WidgetBundle {

    @WidgetBundleBuilder
    var body: some Widget {
        DashboardWidget()
        FilesWidget()
        ToolbarWidget()
        LockscreenWidget()
    }
}

struct DashboardWidget: Widget {
    let kind: String = "DashboardWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: DashboardIntent.self, provider: DashboardWidgetProvider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Dashboard")
        .description(NSLocalizedString("_description_dashboardwidget_", comment: ""))
#if !targetEnvironment(simulator)
        .contentMarginsDisabled()
#endif
    }
}

struct FilesWidget: Widget {
    let kind: String = "FilesWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: AccountIntent.self, provider: FilesWidgetProvider()) { entry in
            FilesWidgetView(entry: entry)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Files")
        .description(NSLocalizedString("_description_fileswidget_", comment: ""))
#if !targetEnvironment(simulator)
        .contentMarginsDisabled()
#endif
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
#if !targetEnvironment(simulator)
        .contentMarginsDisabled()
#endif
    }
}

struct LockscreenWidget: Widget {
    let kind: String = "LockscreenWidget"

    var body: some WidgetConfiguration {
        if #available(iOSApplicationExtension 16.0, *) {
            return IntentConfiguration(kind: kind, intent: AccountIntent.self, provider: LockscreenWidgetProvider()) { entry in
                LockscreenWidgetView(entry: entry)
            }
            .supportedFamilies([.accessoryRectangular, .accessoryCircular])
            .configurationDisplayName(NSLocalizedString("_title_lockscreenwidget_", comment: ""))
            .description(NSLocalizedString("_description_lockscreenwidget_", comment: ""))
#if !targetEnvironment(simulator)
            .contentMarginsDisabled()
#endif
        } else {
            return EmptyWidgetConfiguration()
        }
    }
}

extension View {
    func widgetBackground(_ backgroundView: some View) -> some View {
#if !targetEnvironment(simulator)
        if #available(iOSApplicationExtension 17.0, *) {
            return containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            return background(backgroundView)
        }
#else
        return background(backgroundView)
#endif

    }
}
