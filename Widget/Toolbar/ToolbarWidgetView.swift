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
        let linkActionVoiceMemo: URL = URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink)! : URL(string: NCGlobal.shared.widgetActionVoiceMemo)!

        GeometryReader { geo in

            ZStack(alignment: .topLeading) {
				
                HStack(spacing: 0) {
					
					let height: CGFloat = 60
                    let width = geo.size.width / 3

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionUploadAsset, label: {
						Image(uiImage: UIImage(resource: .media))
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(.text))
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandElement))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: width, height: height)
                    })

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionScanDocument, label: {
						Image(uiImage: UIImage(resource: .scan))
                            .resizable()
                            .renderingMode(.template)
                            .font(Font.system(.body).weight(.light))
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(.text))
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandElement))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: width, height: height)
                    })
					
					Link(destination: entry.isPlaceholder ? linkNoAction : linkActionVoiceMemo, label: {
						Image(uiImage: UIImage(resource: .mic))
							.resizable()
							.foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(.text))
							.background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandElement))
							.clipShape(Circle())
							.scaledToFit()
							.frame(width: width, height: height)
					})
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
				.padding(.vertical, geo.size.height / 2 * -0.25)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

                FooterView(imageName: entry.footerImage,
                           text: entry.footerText,
                           isPlaceholder: entry.isPlaceholder)
                    .padding(.horizontal, 15.0)
                    .padding(.bottom, 10.0)
                    .frame(maxWidth: geo.size.width - 5,
                           maxHeight: geo.size.height - 2,
                           alignment: .bottomTrailing)
            }
        }
        .widgetBackground(Color(.background))
    }
}

struct ToolbarWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = ToolbarDataEntry(date: Date(), isPlaceholder: false, userId: "", url: "", account: "", footerImage: "Cloud_Checkmark", footerText: NCBrandOptions.shared.brand + " toolbar")
        ToolbarWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
