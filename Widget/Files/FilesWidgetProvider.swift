// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WidgetKit
import Intents
import SwiftUI

struct FilesWidgetProvider: IntentTimelineProvider {
    typealias Entry = FilesDataEntry
    typealias Intent = AccountIntent

    func placeholder(in context: Context) -> Entry {
        let datasPlaceholder = Array(filesDatasTest[0...4])
        let title = getTitleFilesWidget(tableAccount: nil)
        return Entry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, isEmpty: false, userId: "", url: "", account: "", tile: title, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " files")
    }

    func getSnapshot(for configuration: AccountIntent, in context: Context, completion: @escaping (Entry) -> Void) {
        Task {
            let entry = await getFilesDataEntry(configuration: configuration, isPreview: false, displaySize: context.displaySize)
            completion(entry)
        }
    }

    func getTimeline(for configuration: AccountIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let entry = await getFilesDataEntry(configuration: configuration, isPreview: context.isPreview, displaySize: context.displaySize)
            let timeLine = Timeline(entries: [entry], policy: .atEnd)
            completion(timeLine)
        }
    }
}
