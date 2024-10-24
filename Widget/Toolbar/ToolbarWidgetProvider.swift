//
//  ToolbarWidgetProvider.swift
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
