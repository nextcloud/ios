// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WidgetKit
import Intents
import SwiftUI

struct LockscreenWidgetProvider: IntentTimelineProvider {
    typealias Entry = LockscreenData
    typealias Intent = AccountIntent

    func placeholder(in context: Context) -> Entry {
        return Entry(date: Date(), isPlaceholder: true, activity: "", link: nil, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: false)
    }

    func getSnapshot(for configuration: AccountIntent, in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview {
            completion(Self.previewEntry())
            return
        }
        getLockscreenDataEntry(configuration: configuration, family: context.family) { entry in
            completion(entry)
        }
    }

    func getTimeline(for configuration: AccountIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        if context.isPreview {
            completion(Timeline(entries: [Self.previewEntry()], policy: .never))
            return
        }
        getLockscreenDataEntry(configuration: configuration, family: context.family) { entry in
            let timeLine = Timeline(entries: [entry], policy: .atEnd)
            completion(timeLine)
        }
    }

    static func previewEntry() -> Entry {
        Entry(date: Date(), isPlaceholder: false, activity: "Alex updated Documents / Meeting notes.pdf",
              link: nil, quotaRelative: 0.5, quotaUsed: "5 GB", quotaTotal: "10 GB", error: false)
    }
}
