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
                
                /*
                HStack(spacing: 5) {
                    
                    Text(NCBrandOptions.shared.brand)
                        .font(.system(size: 13))
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                }
                .padding(.leading, 10)
                .padding(.top, 10)
                */
                
                VStack(alignment: .leading) {
                    
                    VStack(spacing: 0) {
                        
                        let recentDatasCount = CGFloat(entry.recentDatas.count)
                        let heightFrame = (geo.size.height - 120) / recentDatasCount
                        let addSizeIcon = heightFrame / recentDatasCount
                        let spacing = (addSizeIcon - recentDatasCount) / 2
                        
                        ForEach(entry.recentDatas, id: \.id) { element in
                            
                            Link(destination: element.url) {
                                
                                HStack {
                                    
                                    let subTitleColor = Color(white: 0.5)
                                    let imageSize:CGFloat = 30
                                    
                                    Image(uiImage: element.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: imageSize+addSizeIcon, height: imageSize+addSizeIcon)
                                        .clipped()
                                        .cornerRadius(5)
                                    
                                    VStack(alignment: .leading, spacing: spacing) {
                                        
                                        Text(element.title)
                                            .font(.system(size: 12))
                                            .fontWeight(.regular)
                                        
                                        Text(element.subTitle)
                                            .font(.system(size: CGFloat(10)))
                                            .foregroundColor(subTitleColor)
                                    }
                                    Spacer()
                                }
                                .padding(.leading, 10)
                                .frame(height: heightFrame)
                            }
                            Divider()
                                .padding(.leading, 48 + addSizeIcon)
                        }
                    }
                }
                .padding(.top, 10)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

                HStack(spacing: 0) {

                    let sizeButton: CGFloat = 50
                    let placeholderColor = Color(white: 0.8)
                    let brandColor = Color(NCBrandColor.shared.brand)
                    let brandTextColor = Color(NCBrandColor.shared.brandText)
                    
                    Link(destination: entry.isPlaceholder ? NCGlobal.shared.widgetActionNoAction : NCGlobal.shared.widgetActionUploadAsset, label: {
                        Image("buttonAddImage")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? placeholderColor : brandTextColor)
                            .padding(10)
                            .background(entry.isPlaceholder ? placeholderColor : brandColor)
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })

                    Link(destination: entry.isPlaceholder ? NCGlobal.shared.widgetActionNoAction : NCGlobal.shared.widgetActionScanDocument, label: {
                        Image("buttonAddScan")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? placeholderColor : brandTextColor)
                            .padding(10)
                            .background(entry.isPlaceholder ? placeholderColor : brandColor)
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })

                    Link(destination: entry.isPlaceholder ? NCGlobal.shared.widgetActionNoAction : NCGlobal.shared.widgetActionTextDocument, label: {
                        Image("note.text")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? placeholderColor : brandTextColor)
                            .padding(10)
                            .background(entry.isPlaceholder ? placeholderColor : brandColor)
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })

                    Link(destination: entry.isPlaceholder ? NCGlobal.shared.widgetActionNoAction : NCGlobal.shared.widgetActionVoiceMemo, label: {
                        Image("microphone")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? placeholderColor : brandTextColor)
                            .padding(10)
                            .background(entry.isPlaceholder ? placeholderColor : brandColor)
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })
                }
                .frame(width: geo.size.width, height: geo.size.height - 35, alignment: .bottomTrailing)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

                HStack {

                    let placeholderColor = Color(white: 0.2)
                    let brandColor = Color(NCBrandColor.shared.brand)

                    Image(systemName: entry.footerImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(entry.isPlaceholder ? placeholderColor : brandColor)
                    
                    Text(entry.footerText)
                        .font(.caption2)
                        .padding(.trailing, 13.0)
                }
                .frame(maxWidth: geo.size.width - 5, maxHeight: geo.size.height - 2, alignment: .bottomTrailing)
            }
        }
    }
}

struct NextcloudWidget_Previews: PreviewProvider {
    static var previews: some View {
        let recentDatas = Array(recentDatasTest[0...3])
        let entry = NextcloudDataEntry(date: Date(), recentDatas: recentDatas, isPlaceholder: false, footerImage: "checkmark.icloud", footerText: "Nextcloud widget")
        NextcloudWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
