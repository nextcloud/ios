// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents
import WidgetKit
import Intents

struct DashboardWidgetProvider: IntentTimelineProvider {
    typealias Intent = DashboardIntent
    typealias Entry = DashboardDataEntry

    func placeholder(in context: Context) -> Entry {
        dashboardPlaceholder(height: context.displaySize.height)
    }

    func getSnapshot(for configuration: DashboardIntent, in context: Context, completion: @escaping (Entry) -> Void) {
        guard !context.isPreview else {
            completion(placeholder(in: context))
            return
        }

        Task {
            completion(await getDashboardDataEntry(configuration: configuration, displaySize: context.displaySize))
        }
    }

    func getTimeline(for configuration: DashboardIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        guard !context.isPreview else {
            completion(Timeline(entries: [placeholder(in: context)], policy: .never))
            return
        }

        Task {
            let entry = await getDashboardDataEntry(configuration: configuration, displaySize: context.displaySize)
            completion(Timeline(entries: [entry], policy: .atEnd))
        }
    }
}

struct RefreshDashboardWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Dashboard"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        // WidgetKit reloads this widget's timeline after its button intent completes.
        return .result()
    }
}
