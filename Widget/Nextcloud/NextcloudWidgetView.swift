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
                    Text(NCBrandOptions.shared.brand)
                        .font(.system(size: 13))
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                }
                .padding(.leading, 10)
                .padding(.top, 10)
                VStack(alignment: .leading) {
                    VStack(spacing: 0) {
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
                                            .fontWeight(.regular)
                                        Text(element.subTitle)
                                            .font(.system(size: CGFloat(10)))
                                            .foregroundColor(Color(white: 0.5))
                                        Divider()
                                    }
                                    .padding(.top, 6.0)
                                    Spacer()
                                }
                                .padding(.leading, 10)
                                .frame(height: (geo.size.height-110)/CGFloat(entry.recentDatas.count))
                            }
                        }
                    }
                }
                .padding(.top, 35)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

                HStack(spacing: 0) {

                    Link(destination: URL(string: "nextcloud://open-action?action=upload-asset")!, label: {
                        Image("buttonAddImage")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width/4, height: 45)
                    })

                    Link(destination: URL(string: "nextcloud://open-action?action=add-scan-document")!, label: {
                        Image("buttonAddScan")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width/4, height: 45)
                    })

                    Link(destination: URL(string: "nextcloud://open-action?action=create-text-document")!, label: {
                        Image("note.text")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width/4, height: 45)
                    })

                    Link(destination: URL(string: "nextcloud://open-action?action=create-voice-memo")!, label: {
                        Image("microphone")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width/4, height: 45)
                    })
                }
                .frame(width: geo.size.width, height: geo.size.height-25, alignment: .bottomTrailing)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

                HStack {

                    Image(systemName: entry.footerImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(entry.isPlaceholder ? Color(white: 0.2) : Color(NCBrandColor.shared.brand))
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
        let recentDatas = Array(recentDatasTest[0...2])
        let entry = NextcloudDataEntry(date: Date(), recentDatas: recentDatas, isPlaceholder: false, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " widget")
        NextcloudWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
