//
//  LockscreenWidgetView.swift
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

import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.0, *)
struct LockscreenWidgetView: View {

    var entry: LockscreenData

    var body: some View {
        HStack {
            Text(entry.displayName)
            Gauge(
                value: entry.quotaRelative,
                label: { Text(entry.quotaTotal) },
                currentValueLabel: { Text(entry.quotaUsed) }
            )
            .gaugeStyle(.accessoryCircular)
        }
    }
}

@available(iOSApplicationExtension 16.0, *)
struct LockscreenWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        let entry = LockscreenData(date: Date(), isPlaceholder: true, displayName: "Marino Faggiana", quotaRelative: 0.5, quotaUsed: "22 GB", quotaTotal: "50 GB")
        LockscreenWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
