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

    let entry: LockscreenData
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            if entry.error {
                Gauge(
                    value: 0,
                    label: {},
                    currentValueLabel: {
                        Image(systemName: "xmark.icloud")
                            .font(.system(size: 25.0))
                    }
                )
                .gaugeStyle(.accessoryCircularCapacity)
            } else {
                Gauge(
                    value: entry.quotaRelative,
                    label: {
                        Text(" " + entry.quotaTotal + " ")
                            .font(.system(size: 8.0))
                    },
                    currentValueLabel: {
                        Text(entry.quotaUsed)
                    }
                )
                .gaugeStyle(.accessoryCircular)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 1) {
                    Image("activity")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFill()
                        .foregroundColor(.gray)
                        .frame(width: 11, height: 11)
                    Text(NSLocalizedString("_recent_activity_", comment: ""))
                        .font(.system(size: 11))
                        .fontWeight(.heavy)
                        .foregroundColor(.gray)
                }
                if entry.error {
                    VStack(spacing: 1) {
                        Image(systemName: "xmark.icloud")
                            .font(.system(size: 25.0))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }.padding(8)
                } else {
                    Text(entry.activity)
                        .font(.system(size: 12)).bold()
                }
            }
            .widgetURL(entry.link)
            .redacted(reason: entry.isPlaceholder ? .placeholder : [])
        default:
            Text("Not implemented")
        }
    }
}

@available(iOSApplicationExtension 16.0, *)
struct LockscreenWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        let entry = LockscreenData(date: Date(), isPlaceholder: false, activity: "Alba Mayoral changed Marketing / Regional Marketing / Agenda Meetings / Q4 2022 / OCTOBER / 13.11 Afrah Kahlid.md", link: URL(string: "https://")!, quotaRelative: 0.5, quotaUsed: "999 GB", quotaTotal: "999 GB", error: false)
        LockscreenWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .accessoryRectangular)).previewDisplayName("Rectangular")
        LockscreenWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .accessoryCircular)).previewDisplayName("Circular")
    }
}
