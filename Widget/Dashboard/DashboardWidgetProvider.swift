// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WidgetKit
import Intents
import SwiftUI

struct DashboardWidgetProvider: IntentTimelineProvider {
    typealias Intent = DashboardIntent
    typealias Entry = DashboardDataEntry

    func placeholder(in context: Context) -> Entry {
        let dashboardItems = getDashboardItems(displaySize: context.displaySize, withButton: false)
        let datasPlaceholder = Array(dashboardDatasTest[0...dashboardItems])
        let title = "Dashboard"
        let titleImage = UIImage(systemName: "circle.fill") ?? UIImage()
        return Entry(date: Date(), datas: datasPlaceholder, dashboard: nil, buttons: nil, isPlaceholder: true, isEmpty: false, titleImage: titleImage, title: title, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " widget", account: "")
    }

    func getSnapshot(for configuration: DashboardIntent, in context: Context, completion: @escaping (DashboardDataEntry) -> Void) {
        Task {
            let entry = await getDashboardDataEntry(configuration: configuration, isPreview: false, displaySize: context.displaySize)
            completion(entry)
        }
    }

    func getTimeline(for configuration: DashboardIntent, in context: Context, completion: @escaping (Timeline<DashboardDataEntry>) -> Void) {
        Task {
            let entry = await getDashboardDataEntry(configuration: configuration, isPreview: context.isPreview, displaySize: context.displaySize)
            let timeLine = Timeline(entries: [entry], policy: .atEnd)
            completion(timeLine)
        }
    }
}
