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
        return Entry(date: Date(), isPlaceholder: true, activity: "", link: URL(string: "https://")!, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: false)
    }

    func getSnapshot(for configuration: AccountIntent, in context: Context, completion: @escaping (Entry) -> Void) {
        getLockscreenDataEntry(configuration: configuration, isPreview: false, family: context.family) { entry in
            completion(entry)
        }
    }

    func getTimeline(for configuration: AccountIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        getLockscreenDataEntry(configuration: configuration, isPreview: context.isPreview, family: context.family) { entry in
            let timeLine = Timeline(entries: [entry], policy: .atEnd)
            completion(timeLine)
        }
    }
}
