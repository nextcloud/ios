//
//  DashboardWidgetView.swift
//  Widget
//
//  Created by Marino Faggiana on 20/08/22.
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

/*
 @Environment(\.colorScheme) var colorScheme

     var entry: Provider.Entry

     var bgColor: some View {
         colorScheme == .dark ? Color.red : Color.orange
     }

     var body: some View {
         ZStack {
             bgColor
             Text(entry.date, style: .time)
         }
     }
 */

struct DashboardWidgetView: View {
    var entry: DashboardDataEntry
    var placeholderColor = Color(red: 0.9, green: 0.9, blue: 0.92)
    let date = Date().formatted()

    var body: some View {
        switch entry.dashboardDatas.isEmpty {
        case true:
            emptyDasboardView
        case false:
            bodyDasboardView
        }
    }

    var emptyDasboardView: some View {
        VStack(alignment: .center) {
            Text("")
                .frame(maxWidth: 280, minHeight: 20)
                .background(placeholderColor)
                .padding(5)
            VStack {
                ForEach(1...5, id: \.self) { _ in
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 40.0))
                            .foregroundColor(placeholderColor)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("")
                                .frame(maxWidth: .infinity)
                                .background(placeholderColor)
                            Text("")
                                .frame(maxWidth: .infinity)
                                .background(placeholderColor)
                        }
                        Spacer()
                    }
                    .padding(5)
                }
            }
        }.padding(5)
    }

    var bodyDasboardView: some View {
        VStack(alignment: .center) {
            Text("\(date)")
                .font(.title)
                .bold()
            VStack {
                ForEach(entry.dashboardDatas, id: \.id) { element in
                    Link(destination: element.url) {
                        HStack {
                            Image(element.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            VStack(alignment: .leading) {
                                Text(element.title)
                                    .font(.headline)
                                Text(element.subTitle)
                                    .font(.subheadline)
                                    .foregroundColor(Color(white: 0.4745))
                            }
                            Spacer()
                        }
                        .padding(5)
                    }
                }
            }
        }.padding(5)
    }
}

struct NCElementDashboard_Previews: PreviewProvider {
    static var previews: some View {
        let entry = DashboardDataEntry(date: Date(), dashboardDatas: []) // dashboardDatasTest
        DashboardWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
