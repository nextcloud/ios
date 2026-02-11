// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
        return IntentConfiguration(kind: kind, intent: AccountIntent.self, provider: LockscreenWidgetProvider()) { entry in
            LockscreenWidgetView(entry: entry)
        }
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
        .configurationDisplayName(NSLocalizedString("_title_lockscreenwidget_", comment: ""))
        .description(NSLocalizedString("_description_lockscreenwidget_", comment: ""))
#if !targetEnvironment(simulator)
        .contentMarginsDisabled()
#endif
    }
}

extension View {
    func widgetBackground(_ backgroundView: some View) -> some View {
#if !targetEnvironment(simulator)
        return containerBackground(for: .widget) {
            backgroundView
        }
#else
        return background(backgroundView)
#endif

    }
}
