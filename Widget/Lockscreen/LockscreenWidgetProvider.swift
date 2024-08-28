//
//  LockscreenWidgetProvider.swift
//  Widget
//
//  Created by Marino Faggiana on 13/10/22.
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
