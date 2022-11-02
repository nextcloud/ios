//
//  FilesWidgetView.swift
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

struct FilesWidgetView: View {
    
    var entry: FilesDataEntry

    var body: some View {

        let parameterLink = "&user=\(entry.userId)&url=\(entry.url)"
        let linkNoAction: URL = URL(string: NCGlobal.shared.widgetActionNoAction + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionNoAction + parameterLink)! : URL(string: NCGlobal.shared.widgetActionNoAction)!
        let linkActionUploadAsset: URL = URL(string: NCGlobal.shared.widgetActionUploadAsset + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionUploadAsset + parameterLink)! : URL(string: NCGlobal.shared.widgetActionUploadAsset)!
        let linkActionScanDocument: URL = URL(string: NCGlobal.shared.widgetActionScanDocument + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionScanDocument + parameterLink)! : URL(string: NCGlobal.shared.widgetActionScanDocument)!
        let linkActionTextDocument: URL = URL(string: NCGlobal.shared.widgetActionTextDocument + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionTextDocument + parameterLink)! : URL(string: NCGlobal.shared.widgetActionTextDocument)!
        let linkActionVoiceMemo: URL = URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink)! : URL(string: NCGlobal.shared.widgetActionVoiceMemo)!

        GeometryReader { geo in

            if entry.isEmpty {
                VStack(alignment: .center) {
                    Image(systemName: "checkmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                    Text(NSLocalizedString("_no_items_", comment: ""))
                        .font(.system(size: 25))
                        .padding()
                    Text(NSLocalizedString("_check_back_later_", comment: ""))
                        .font(.system(size: 15))
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }

            ZStack(alignment: .topLeading) {
                
                HStack() {
                    
                    Text(entry.tile)
                        .font(.system(size: 12))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .textCase(.uppercase)
                        .lineLimit(1)
                }
                .frame(width: geo.size.width - 20)
                .padding([.top, .leading, .trailing], 10)

                if !entry.isEmpty {
                    VStack(alignment: .leading) {

                        VStack(spacing: 0) {

                            ForEach(entry.datas, id: \.id) { element in

                                Link(destination: element.url) {

                                    HStack {

                                        Image(uiImage: element.image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 35, height: 35)
                                            .clipped()
                                            .cornerRadius(5)

                                        VStack(alignment: .leading, spacing: 2) {

                                            Text(element.title)
                                                .font(.system(size: 12))
                                                .fontWeight(.regular)

                                            Text(element.subTitle)
                                                .font(.system(size: CGFloat(10)))
                                                .foregroundColor(Color(.systemGray))
                                        }
                                        Spacer()
                                    }
                                    .padding(.leading, 10)
                                    .frame(height: 50)
                                }
                                Divider()
                                    .padding(.leading, 54)
                            }
                        }
                    }
                    .padding(.top, 30)
                    .redacted(reason: entry.isPlaceholder ? .placeholder : [])
                }

                HStack(spacing: 0) {

                    let sizeButton: CGFloat = 40

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionUploadAsset, label: {
                        Image("addImage")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandText))
                            .padding(11)
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionScanDocument, label: {
                        Image("scan")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandText))
                            .padding(11)
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionTextDocument, label: {
                        Image("note.text")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandText))
                            .padding(11)
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionVoiceMemo, label: {
                        Image("microphone")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandText))
                            .padding(11)
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })
                }
                .frame(width: geo.size.width, height: geo.size.height - 25, alignment: .bottomTrailing)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

                HStack {

                    Image(systemName: entry.footerImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brand))
                
                    Text(entry.footerText)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brand))
                }
                .padding(.horizontal, 15.0)
                .frame(maxWidth: geo.size.width, maxHeight: geo.size.height - 2, alignment: .bottomTrailing)
            }
        }
    }
}

struct FilesWidget_Previews: PreviewProvider {
    static var previews: some View {
        let datas = Array(filesDatasTest[0...4])
        let entry = FilesDataEntry(date: Date(), datas: datas, isPlaceholder: false, isEmpty: true, userId: "", url: "", tile: "Good afternoon, Marino Faggiana", footerImage: "checkmark.icloud", footerText: "Nextcloud files")
        FilesWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
