//
//  ToolbarWidgetView.swift
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

struct ToolbarWidgetView: View {

    var entry: ToolbarDataEntry

    var body: some View {

        let parameterLink = "&user=\(entry.userId)&url=\(entry.url)"
        let linkNoAction: URL = URL(string: NCGlobal.shared.widgetActionNoAction + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionNoAction + parameterLink)! : URL(string: NCGlobal.shared.widgetActionNoAction)!
        let linkActionUploadAsset: URL = URL(string: NCGlobal.shared.widgetActionUploadAsset + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionUploadAsset + parameterLink)! : URL(string: NCGlobal.shared.widgetActionUploadAsset)!
        let linkActionScanDocument: URL = URL(string: NCGlobal.shared.widgetActionScanDocument + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionScanDocument + parameterLink)! : URL(string: NCGlobal.shared.widgetActionScanDocument)!
        let linkActionTextDocument: URL = URL(string: NCGlobal.shared.widgetActionTextDocument + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionTextDocument + parameterLink)! : URL(string: NCGlobal.shared.widgetActionTextDocument)!
        let linkActionVoiceMemo: URL = URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink)! : URL(string: NCGlobal.shared.widgetActionVoiceMemo)!

        GeometryReader { geo in

            ZStack(alignment: .topLeading) {

                Color(.black).opacity(0.9)
                    .ignoresSafeArea()

                HStack(spacing: 0) {

                    let sizeButton: CGFloat = 65

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionUploadAsset, label: {
                        Image("addImage")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandText))
                            .padding()
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
                            .padding()
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
                            .padding()
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionVoiceMemo, label: {
                        Image("microphone")
                            .resizable()
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandText))
                            .padding()
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

                HStack {

                    Image(systemName: entry.footerImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brand))

                    Text(entry.footerText)
                        .font(.caption2)
                        .padding(.trailing, 13.0)
                        .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brand))
                }
                .frame(maxWidth: geo.size.width - 5, maxHeight: geo.size.height - 2, alignment: .bottomTrailing)
            }
        }
    }
}

struct ToolbarWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = ToolbarDataEntry(date: Date(), isPlaceholder: false, userId: "", url: "", footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " toolbar")
        ToolbarWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
