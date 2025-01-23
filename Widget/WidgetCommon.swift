//
//  WidgetCommon.swift
//  Widget
//
//  Created by Oleh Shcherba on 20.11.2024.
//  Copyright © 2024 STRATO GmbH
//

import SwiftUI

struct WidgetConstants {
	static let bottomTextFont: Font = .system(size: 16)
	static let bottomImageWidthHeight = 16.0
	static let elementIconWidthHeight = 36.0
    static let titleTextFont: Font = .system(size: 24, weight: .semibold)
	static let elementTileFont: Font = .system(size: 16, weight: .semibold)
	static let elementSubtitleFont: Font = .system(size: 14, weight: .semibold)
}

struct EmptyWidgetContentView: View {
	var body: some View {
		VStack(alignment: .center) {
			Image(systemName: "checkmark")
				.resizable()
				.scaledToFit()
				.font(Font.system(.body).weight(.light))
                .foregroundStyle(Color(.title))
				.frame(width: 50, height: 50)
			Text(NSLocalizedString("_no_items_", comment: ""))
				.font(.system(size: 25))
				.foregroundStyle(Color(.title))
				.padding()
			Text(NSLocalizedString("_check_back_later_", comment: ""))
				.font(.system(size: 15))
				.foregroundStyle(Color(.title))
		}
	}
}

struct HeaderView: View {
	let title: String
	
	var body: some View {
        Text(title.firstUppercased)
			.font(WidgetConstants.titleTextFont)
			.foregroundStyle(Color(.title))
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
                .foregroundColor(isPlaceholder ? Color(.systemGray4) : Color(.bottomElementForeground))
			
			Text(text)
				.font(WidgetConstants.bottomTextFont)
				.lineLimit(1)
				.minimumScaleFactor(0.7)
                .foregroundColor(isPlaceholder ? Color(.systemGray4) : Color(.bottomElementForeground))
		}
	}
}
