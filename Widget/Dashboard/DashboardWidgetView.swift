//
//  DashboardWidgetView.swift
//  Widget
//
//  Created by Marino Faggiana on 20/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//  Copyright © 2024 STRATO AG
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

struct DashboardWidgetView: View {
    var entry: DashboardDataEntry
    var body: some View {
        GeometryReader { geo in
            if entry.isEmpty {
				EmptyWidgetContentView()
					.frame(width: geo.size.width, height: geo.size.height)
            }

            ZStack(alignment: .topLeading) {
				HeaderView(title: entry.title)
					.padding(.top, 7)
				
                if !entry.isEmpty {

                    VStack(alignment: .leading) {

                        VStack(spacing: 0) {

                            ForEach(entry.datas, id: \.id) { element in

                                Link(destination: element.link) {

                                    HStack {

                                        if entry.isPlaceholder {
                                            Circle()
                                                .fill(Color(.systemGray4))
                                                .frame(width: WidgetConstants.elementIconWidthHeight,
													   height: WidgetConstants.elementIconWidthHeight)
                                        } else if let color = element.imageColor {
                                            Image(uiImage: element.icon)
                                                .renderingMode(.template)
                                                .resizable()
                                                .frame(width: 20, height: 20)
                                                .foregroundColor(Color(color))
                                        } else if element.template {
                                            if entry.dashboard?.itemIconsRound ?? false {
                                                Image(uiImage: element.icon)
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 20, height: 20)
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .background(Color(.systemGray4))
                                                    .clipShape(Circle())
                                            } else {
                                                Image(uiImage: element.icon)
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: WidgetConstants.elementIconWidthHeight,
														   height: WidgetConstants.elementIconWidthHeight)
                                                    .foregroundStyle(Color(uiColor:NCBrandColor.shared.iconImageColor2))
                                                    .clipped()
                                            }
                                        } else {
                                            if entry.dashboard?.itemIconsRound ?? false || element.avatar {
                                                Image(uiImage: element.icon)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: WidgetConstants.elementIconWidthHeight,
														   height: WidgetConstants.elementIconWidthHeight)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(uiImage: element.icon)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: WidgetConstants.elementIconWidthHeight,
														   height: WidgetConstants.elementIconWidthHeight)
                                                    .clipped()
                                            }
                                        }

										VStack(alignment: .leading, spacing: 2) {
											Text(element.title)
												.font(WidgetConstants.elementTileFont)
                                                .foregroundStyle(Color(.title))
                                            if !element.subTitle.isEmpty {
                                                Text(element.subTitle)
                                                    .font(WidgetConstants.elementSubtitleFont)
                                                    .foregroundStyle(Color(.subtitle))
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.leading, 10)
                                    .frame(height: 50)
                                }
                                if element != entry.datas.last {
                                    Divider()
                                        .overlay(Color(.divider))
                                }
                            }
                        }
                    }
                    .padding(.top, 40)
                    .redacted(reason: entry.isPlaceholder ? .placeholder : [])
                }

                if let buttons = entry.buttons, !buttons.isEmpty, !entry.isPlaceholder {

                    HStack(spacing: 10) {

                        let brandColor = Color(NCBrandColor.shared.brandElement)
                        let brandTextColor = Color(.text)

                        ForEach(buttons, id: \.index) { element in
                            Link(destination: URL(string: element.link)!, label: {

                                Text(element.text)
                                    .font(.system(size: 15))
                                    .padding(7)
                                    .background(brandColor)
                                    .foregroundColor(brandTextColor)
                                    .border(brandColor, width: 1)
                                    .cornerRadius(.infinity)
                                    .padding(.bottom, 12)
                            })
                        }
                    }
                    .frame(width: geo.size.width - 10, height: geo.size.height - 25, alignment: .bottomTrailing)
                }

                FooterView(imageName: entry.footerImage,
                           text: entry.footerText,
                           isPlaceholder: entry.isPlaceholder)
                    .padding(.horizontal, 15.0)
                    .padding(.bottom, 10.0)
                    .frame(maxWidth: geo.size.width,
                           maxHeight: geo.size.height - 2,
                           alignment: .bottomTrailing)
            }
        }
        .widgetBackground(Color(.background))
    }
}

struct DashboardWidget_Previews: PreviewProvider {
    static var previews: some View {
        let datas = Array(dashboardDatasTest[0...4])
        let title = "Dashboard"
        let titleImage = UIImage(named: "widget")!
        let entry = DashboardDataEntry(date: Date(), datas: datas, dashboard: nil, buttons: nil, isPlaceholder: false, isEmpty: true, titleImage: titleImage, title: title, footerImage: "Cloud_Checkmark", footerText: "Nextcloud widget", account: "")
        DashboardWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
