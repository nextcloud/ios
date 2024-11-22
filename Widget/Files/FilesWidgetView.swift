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

		GeometryReader { geo in
			if entry.isEmpty {
				EmptyWidgetContentView()
					.frame(width: geo.size.width, height: geo.size.height)
			}
			
			HeaderView(entry: entry)
				.padding(.top, 7)
			
			VStack(spacing: 5) {
				
				if !entry.isEmpty {
					WidgetContentView(entry: entry)
						.padding(.top, 35)
						.redacted(reason: entry.isPlaceholder ? .placeholder : [])
				}
				Spacer()
				
				LinkActionsToolbarView(entry: entry, geo: geo)
					.frame(width: geo.size.width,
						   height: 48,
						   alignment: .bottomTrailing)
					.redacted(reason: entry.isPlaceholder ? .placeholder : [])
				
				FooterView(entry: entry)
					.padding(.horizontal, 15.0)
					.padding(.bottom, 10.0)
					.frame(maxWidth: geo.size.width,
						   maxHeight: 30,
						   alignment: .bottomTrailing)
			}
		}
		.widgetBackground(Color(UIColor(resource: .background)))
    }
}

fileprivate struct EmptyWidgetContentView: View {
	var body: some View {
		VStack(alignment: .center) {
			Image(systemName: "checkmark")
				.resizable()
				.scaledToFit()
				.font(Font.system(.body).weight(.light))
				.frame(width: 50, height: 50)
			Text(NSLocalizedString("_no_items_", comment: ""))
				.font(.system(size: 25))
				.padding()
			Text(NSLocalizedString("_check_back_later_", comment: ""))
				.font(.system(size: 15))
		}
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
									.foregroundColor(Color(NCBrandColor.shared.iconImageColor))
									.scaledToFit()
									.frame(width: 32, height: 32)
							} else {
								Image(uiImage: element.image)
									.resizable()
									.scaledToFill()
									.frame(width: 32, height: 32)
									.clipped()
									.cornerRadius(5)
							}
							
							VStack(alignment: .leading, spacing: 2) {
								Text(element.title)
									.font(.system(size: 16))
									.fontWeight(.regular)
								Text(element.subTitle)
									.font(.system(size: CGFloat(10)))
									.foregroundColor(Color(NCBrandColor.shared.iconImageColor2))
							}
							Spacer()
						}
						.padding(.leading, 10)
						.frame(height: 50)
					}
					if element != entry.datas.last {
						Divider()
							.overlay(Color(UIColor(resource: .divider)))
					}
				}
			}
		}
	}
}

struct HeaderView: View {
	let entry: FilesDataEntry
	
	var body: some View {
		Text(entry.tile)
			.font(WidgetConstants.titleTextFont)
			.multilineTextAlignment(.center)
			.lineLimit(1)
			.padding(.leading, 13)
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
		let linkActionTextDocument: URL = URL(string: NCGlobal.shared.widgetActionTextDocument + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionTextDocument + parameterLink)! : URL(string: NCGlobal.shared.widgetActionTextDocument)!
		let linkActionVoiceMemo: URL = URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink)! : URL(string: NCGlobal.shared.widgetActionVoiceMemo)!
		
		HStack(spacing: 0) {
			let sizeButton: CGFloat = 48
			
			Link(destination: entry.isPlaceholder ? linkNoAction : linkActionUploadAsset, label: {
				Image(uiImage: UIImage(resource: .media))
					.resizable()
					.renderingMode(.template)
					.foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandText))
					.background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandElement))
					.clipShape(Circle())
					.scaledToFit()
					.frame(width: geo.size.width / 4, height: sizeButton)
			})
			
			Link(destination: entry.isPlaceholder ? linkNoAction : linkActionScanDocument, label: {
				Image(uiImage: UIImage(resource: .scan))
					.resizable()
					.renderingMode(.template)
					.foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandText))
					.background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandElement))
					.clipShape(Circle())
					.scaledToFit()
					.font(Font.system(.body).weight(.light))
					.frame(width: geo.size.width / 4, height: sizeButton)
			})
			
			Link(destination: entry.isPlaceholder ? linkNoAction : linkActionVoiceMemo, label: {
				Image(uiImage: UIImage(resource: .mic))
					.resizable()
					.renderingMode(.template)
					.foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandText))
					.background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandElement))
					.clipShape(Circle())
					.scaledToFit()
					.frame(width: geo.size.width / 4, height: sizeButton)
			})
			
			Link(destination: entry.isPlaceholder ? linkNoAction : linkActionTextDocument, label: {
				Image(uiImage: UIImage(resource: .note))
					.resizable()
					.renderingMode(.template)
					.foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandText))
					.background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.brandElement))
					.clipShape(Circle())
					.scaledToFit()
					.frame(width: geo.size.width / 4, height: sizeButton)
			})
		}
	}
}

struct FooterView: View {
	let entry: FilesDataEntry
	
	var body: some View {
		HStack {
			Image(systemName: entry.footerImage)
				.resizable()
				.scaledToFit()
				.frame(width: WidgetConstants.bottomImageWidthHeight,
					   height: WidgetConstants.bottomImageWidthHeight)
				.font(Font.system(.body).weight(.light))
				.foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(UIColor(resource: .title)))
			
			Text(entry.footerText)
				.font(WidgetConstants.bottomTextFont)
				.lineLimit(1)
				.minimumScaleFactor(0.5)
				.foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(UIColor(resource: .title)))
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
