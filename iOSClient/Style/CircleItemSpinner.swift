//
//  CircleItemSpinner.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 13.09.2024.
//  Copyright © 2024 STRATO GmbH
//

import SwiftUI

struct CircleItemSpinner: View {
	@State private var degree = 270
	let itemsCount: Int = 7
	let itemSide: CGFloat = 8
	let spinerSide: CGFloat = 60
	
	var body: some View {
		GeometryReader { bounds in
			ForEach(0..<itemsCount, id: \.self) { i in
				Circle()
					.fill(.tint)
					.frame(width:itemSide , height: itemSide, alignment: .center)
					.offset(x: (bounds.size.width / 2) - 12)
					.rotationEffect(.degrees(.pi * 2 * Double(i * 7)))
			}
			.frame(width: bounds.size.width, height: bounds.size.height, alignment: .center)
			.rotationEffect(.degrees(Double(degree)))
			.animation(
				Animation.linear(duration: 1.5)
					.repeatForever(autoreverses: false),
				value: degree
			)
			.onAppear{
				degree = 270 + 360
			}
		}
		.frame(width: spinerSide, height: spinerSide)
	}
}

#Preview {
    CircleItemSpinner()
}
