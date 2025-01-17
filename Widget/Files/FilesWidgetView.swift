//
//  FilesWidgetView.swift
//  Widget
//
//  Created by Marino Faggiana on 25/08/22.
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

struct FilesWidgetView: View {

    var entry: FilesDataEntry

    var body: some View {

		GeometryReader { geo in
			if entry.isEmpty {
				EmptyWidgetContentView()
					.frame(width: geo.size.width, height: geo.size.height)
			}
			
            HeaderView(title: entry.tile)
				.padding(.top, 7)
				
			VStack(spacing: 5) {
				
				if !entry.isEmpty {
					WidgetContentView(entry: entry)
						.padding(.top, 40)
						.redacted(reason: entry.isPlaceholder ? .placeholder : [])
				}
				
				Spacer()
				
				LinkActionsToolbarView(entry: entry, geo: geo)
					.frame(width: geo.size.width,
						   height: 48,
						   alignment: .bottom)
					.redacted(reason: entry.isPlaceholder ? .placeholder : [])
				
				FooterView(imageName: entry.footerImage,
						   text: entry.footerText,
						   isPlaceholder: entry.isPlaceholder)
					.padding(.horizontal, 15.0)
					.padding(.bottom, 10.0)
					.frame(maxWidth: geo.size.width,
						   maxHeight: 30,
						   alignment: .bottomTrailing)
			}
		}
        .widgetBackground(Color(.background))
    }
}

fileprivate struct WidgetContentView: View {
	let entry: FilesDataEntry
	
	var body: some View {
		VStack(alignment: .leading) {
			VStack(spacing: 0) {
				ForEach(entry.datas, id: \.id) { element in
					Link(destination: element.url) {
						HStack {
							if element.useTypeIconFile {
								Image(uiImage: element.image)
									.resizable()
									.renderingMode(.template)
									.foregroundStyle(Color(element.color ?? NCBrandColor.shared.iconImageColor))
									.scaledToFit()
									.aspectRatio(1.1, contentMode: .fit)
									.frame(width: WidgetConstants.elementIconWidthHeight,
										   height: WidgetConstants.elementIconWidthHeight)
							} else {
								Image(uiImage: element.image)
									.resizable()
									.scaledToFill()
									.frame(width: WidgetConstants.elementIconWidthHeight,
										   height: WidgetConstants.elementIconWidthHeight)
									.clipped()
							}
							
							VStack(alignment: .leading, spacing: 2) {
								Text(element.title)
									.font(WidgetConstants.elementTileFont)
                                    .foregroundStyle(Color(.title))
								Text(element.subTitle)
									.font(WidgetConstants.elementSubtitleFont)
                                    .foregroundStyle(Color(.subtitle))
							}
							Spacer()
						}
						.padding(.leading, 10)
						.frame(maxHeight: .infinity)
					}
					if element != entry.datas.last {
						Divider()
                            .overlay(Color(.divider))
					}
				}
			}
		}
	}
}

struct LinkActionsToolbarView: View {
	let entry: FilesDataEntry
	let geo: GeometryProxy
	
	var body: some View {
		let parameterLink = "&user=\(entry.userId)&url=\(entry.url)"
		
		let linkNoAction: URL = URL(string: NCGlobal.shared.widgetActionNoAction + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionNoAction + parameterLink)! : URL(string: NCGlobal.shared.widgetActionNoAction)!
		let linkActionUploadAsset: URL = URL(string: NCGlobal.shared.widgetActionUploadAsset + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionUploadAsset + parameterLink)! : URL(string: NCGlobal.shared.widgetActionUploadAsset)!
		let linkActionScanDocument: URL = URL(string: NCGlobal.shared.widgetActionScanDocument + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionScanDocument + parameterLink)! : URL(string: NCGlobal.shared.widgetActionScanDocument)!
		let linkActionVoiceMemo: URL = URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink)! : URL(string: NCGlobal.shared.widgetActionVoiceMemo)!
		
		HStack(spacing: -6) {
            
			let height: CGFloat = 48
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
					.foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(.text))
                    .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandElement))
					.clipShape(Circle())
					.scaledToFit()
					.font(Font.system(.body).weight(.light))
					.frame(width: width, height: height)
			})
			
			Link(destination: entry.isPlaceholder ? linkNoAction : linkActionVoiceMemo, label: {
				Image(uiImage: UIImage(resource: .mic))
					.resizable()
					.renderingMode(.template)
					.foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(.text))
					.background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandElement))
					.clipShape(Circle())
					.scaledToFit()
					.frame(width: width, height: height)
			})
		}
	}
}

struct FilesWidget_Previews: PreviewProvider {
    static var previews: some View {
        let datas = Array(filesDatasTest[0...4])
        let entry = FilesDataEntry(date: Date(), datas: datas, isPlaceholder: false, isEmpty: true, userId: "", url: "", account: "", tile: "Good afternoon, Marino Faggiana", footerImage: "Cloud_Checkmark", footerText: "Nextcloud files")
        FilesWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
