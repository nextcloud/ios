//
//  NextcloudWidgetView.swift
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

import SwiftUI
import WidgetKit

struct NextcloudWidgetView: View {
    var entry: NextcloudDataEntry
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                HStack(spacing: 5) {
                    Image("AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .cornerRadius(4)
                    Text(NCBrandOptions.shared.brand + "")
                        .font(.system(size: 12))
                        .textCase(.uppercase)
                }
                .padding(.leading, 10)
                .padding(.top, 10)
                VStack(alignment: .leading) {
                    VStack(spacing: 6) {
                        ForEach(entry.recentDatas, id: \.id) { element in
                            Link(destination: element.url) {
                                HStack {
                                    Image(uiImage: element.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: imageSize, height: imageSize)
                                        .clipped()
                                        .cornerRadius(4)
                                    VStack(alignment: .leading) {
                                        Text(element.title)
                                            .font(.system(size: 12))
                                            .fontWeight(.bold)
                                        Text(element.subTitle)
                                            .font(.system(size: CGFloat(10)))
                                            .foregroundColor(Color(white: 0.4745))
                                        Divider()
                                    }
                                    Spacer()
                                }
                                .padding(.leading, 10)
                            }
                        }
                    }
                    Spacer()
                        .frame(width: geo.size.width, height: 20.0) // <-----

                    HStack(spacing: 0) {

                        Image("buttonAddImage")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width/4, height: 50)
                            .widgetURL(URL(string: "nextcloud://open-action?action=upload-asset")!)

                        Image("buttonAddScan")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width/4, height: 50)
                            .widgetURL(URL(string: "nextcloud://open-action?action=add-scan-document")!)

                        Image("note.text")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width/4, height: 50)
                            .widgetURL(URL(string: "nextcloud://open-action?action=create-text-document")!)

                        Image("microphone")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width/4, height: 50)
                            .widgetURL(URL(string: "nextcloud://open-action?action=create-voice-memo")!)
                    }
                    .frame(width: geo.size.width, height: 40)
                }
                .padding(.top, 45)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])
                HStack {
                    Image(systemName: entry.footerImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(Color(NCBrandColor.shared.brand))
                    Text(entry.footerText)
                        .font(.caption2)
                        .padding(.trailing, 13.0)
                }
                .frame(maxWidth: geo.size.width, maxHeight: geo.size.height-4, alignment: .bottomTrailing)
            }
        }
    }
}

struct NextcloudWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = NextcloudDataEntry(date: Date(), recentDatas: recentDatasTest, isPlaceholder: false, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " widget")
        NextcloudWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
