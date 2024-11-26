//
//  WidgetCommon.swift
//  Widget
//
//  Created by Oleh Shcherba on 20.11.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

struct WidgetConstants {
	static let bottomTextFont: Font = .custom("SFProText-Regular", size: 16)
	static let bottomImageWidthHeight = 16.0
	static let elementIconWidthHeight = 36.0
	static let titleTextFont: Font = .custom("SFProText-Semibold", size: 24)
	static let elementTileFont: Font = .custom("SFProText-Semibold", size: 16)
	static let elementSubtitleFont: Font = .custom("SFProText-Semibold", size: 14)
}

struct EmptyWidgetContentView: View {
	var body: some View {
		VStack(alignment: .center) {
			Image(systemName: "checkmark")
				.resizable()
				.scaledToFit()
				.font(Font.system(.body).weight(.light))
				.foregroundStyle(Color(UIColor(resource: .title)))
				.frame(width: 50, height: 50)
			Text(NSLocalizedString("_no_items_", comment: ""))
				.font(.system(size: 25))
				.foregroundStyle(Color(UIColor(resource: .title)))
				.padding()
			Text(NSLocalizedString("_check_back_later_", comment: ""))
				.font(.system(size: 15))
				.foregroundStyle(Color(UIColor(resource: .title)))
		}
	}
}

struct HeaderView: View {
	let title: String
	
	var body: some View {
		Text(title)
			.font(WidgetConstants.titleTextFont)
			.foregroundStyle(Color(UIColor(resource: .title)))
			.minimumScaleFactor(0.7)
			.lineLimit(1)
			.padding(.leading, 13)
	}
}

struct FooterView: View {
	let imageName: String
	let text: String
	let isPlaceholder: Bool
	
	var body: some View {
		HStack(spacing: 8) {
			Image(uiImage: UIImage(named: imageName) ?? UIImage())
				.resizable()
				.renderingMode(.template)
				.scaledToFit()
				.frame(width: WidgetConstants.bottomImageWidthHeight,
					   height: WidgetConstants.bottomImageWidthHeight)
				.font(Font.system(.body).weight(.light))
				.foregroundColor(isPlaceholder ? Color(.systemGray4) : Color(UIColor(resource: .bottomElementForeground)))
			
			Text(text)
				.font(WidgetConstants.bottomTextFont)
				.lineLimit(1)
				.minimumScaleFactor(0.7)
				.foregroundColor(isPlaceholder ? Color(.systemGray4) : Color(UIColor(resource: .bottomElementForeground)))
		}
	}
}
