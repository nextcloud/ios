// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WidgetKit
import SwiftUI

struct ToolbarWidgetProvider: TimelineProvider {
    typealias Entry = ToolbarDataEntry

    func placeholder(in context: Context) -> Entry {
        return Entry(date: Date(), isPlaceholder: true, userId: "", url: "", account: "", footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " toolbar")
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        getToolbarDataEntry(isPreview: false) { entry in
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        getToolbarDataEntry(isPreview: context.isPreview) { entry in
            let timeLine = Timeline(entries: [entry], policy: .atEnd)
            completion(timeLine)
        }
    }
}
