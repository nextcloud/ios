//
//  NextcloudWidgetProvider.swift
//  Widget
//
//  Created by Marino Faggiana on 25/08/22.
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

struct NextcloudWidgetProvider: TimelineProvider {

    typealias Entry = NextcloudDataEntry

    func placeholder(in context: Context) -> Entry {
        let datasPlaceholder = Array(recentDatasTest[0...nextcloudItems - 1])
        return Entry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " widget")
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        getNextcloudDataEntry(isPreview: false, displaySize: context.displaySize) { entry in
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        getNextcloudDataEntry(isPreview: context.isPreview, displaySize: context.displaySize) { entry in
            let timeLine = Timeline(entries: [entry], policy: .atEnd)
            completion(timeLine)
        }
    }
}
