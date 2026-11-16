// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents
import WidgetKit
import Intents

struct FilesWidgetProvider: IntentTimelineProvider {
    typealias Entry = FilesDataEntry
    typealias Intent = AccountIntent

    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(),
              datas: filesWidgetSampleRows(count: FilesWidgetLayout.rowCount(for: context.displaySize.height)),
              isPlaceholder: true,
              isEmpty: false,
              allowsRefresh: false,
              footerImage: "checkmark.icloud",
              footerText: NCBrandOptions.shared.brand)
    }

    func getSnapshot(for configuration: AccountIntent, in context: Context, completion: @escaping (Entry) -> Void) {
        guard !context.isPreview else {
            completion(placeholder(in: context))
            return
        }

        Task {
            let entry = await getFilesDataEntry(configuration: configuration, displaySize: context.displaySize)
            completion(entry)
        }
    }

    func getTimeline(for configuration: AccountIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        guard !context.isPreview else {
            completion(Timeline(entries: [placeholder(in: context)], policy: .never))
            return
        }

        Task {
            let entry = await getFilesDataEntry(configuration: configuration, displaySize: context.displaySize)
            completion(Timeline(entries: [entry], policy: .atEnd))
        }
    }
}

struct RefreshFilesWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh recent files"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        // WidgetKit reloads this widget's timeline after its button intent completes.
        return .result()
    }
}
