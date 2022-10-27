//
//  FilesWidgetProvider.swift
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
import Intents
import SwiftUI

struct FilesWidgetProvider: IntentTimelineProvider {

    typealias Entry = FilesDataEntry
    typealias Intent = AccountIntent

    func placeholder(in context: Context) -> Entry {
        let filesItems = getFilesItems(displaySize: context.displaySize)
        let datasPlaceholder = Array(filesDatasTest[0...filesItems - 1])
        let title = getTitleFilesWidget(account: nil)
        return Entry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, isEmpty: false, userId: "", url: "", tile: title, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " files")
    }

    func getSnapshot(for configuration: AccountIntent, in context: Context, completion: @escaping (Entry) -> Void) {
        getFilesDataEntry(configuration: configuration, isPreview: false, displaySize: context.displaySize) { entry in
            completion(entry)
        }
    }

    func getTimeline(for configuration: AccountIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        getFilesDataEntry(configuration: configuration, isPreview: context.isPreview, displaySize: context.displaySize) { entry in
            let timeLine = Timeline(entries: [entry], policy: .atEnd)
            completion(timeLine)
        }
    }
}
