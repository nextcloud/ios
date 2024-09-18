//
//  ButtonStyleGuide.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 13.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

fileprivate class ButtonStyleGuide {
	static let defaultFont			:Font = .title2
	static let defaultBorderWidth	:CGFloat = 3
	static let defaultHeight		:CGFloat = 36
	static var defaultWidth			:CGFloat  = 96
}

// MARK: - Primary
struct ButtonStylePrimary: ButtonStyle {
	@Environment(\.isEnabled) private var isEnabled: Bool
	
	private func foregroundColor(for configuration: Configuration) -> Color {
		isEnabled ? Color(.Button.Primary.Text.normal): Color(.Button.Primary.Text.disabled)
	}
	
	private func backgroundColor(for configuration: Configuration) -> Color {
		if isEnabled {
			return configuration.isPressed ? Color(.Button.Primary.Background.selected) : Color(.Button.Primary.Background.normal)
		}
		return Color(.Button.Primary.Background.disabled)
	}
	
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(ButtonStyleGuide.defaultFont)
			.frame(width: ButtonStyleGuide.defaultWidth, height: ButtonStyleGuide.defaultHeight)
			.padding()
			.foregroundStyle(foregroundColor(for: configuration))
			.background{
				Capsule(style: .circular)
					.stroke(backgroundColor(for: configuration), lineWidth: ButtonStyleGuide.defaultBorderWidth)
					.background(content: {
						Capsule().fill(backgroundColor(for: configuration))
					})
			}
	}
}

extension ButtonStyle where Self == ButtonStylePrimary {
	static var primary: Self {
		return .init()
	}
}

// MARK: - Secondary
struct ButtonStyleSecondary: ButtonStyle {
	@Environment(\.isEnabled) private var isEnabled: Bool
	
	private func foregroundColor(for configuration: Configuration) -> Color {
		if isEnabled {
			return configuration.isPressed ? Color(.Button.Secondary.Text.selected) : Color(.Button.Secondary.Text.normal)
		}
		return Color(.Button.Secondary.Text.disabled)
	}
	
	private func borderColor(for configuration: Configuration) -> Color {
		isEnabled ? Color(.Button.Secondary.Background.selected) : Color(.Button.Secondary.Background.disabled)
	}
	
	private func backgroundColor(for configuration: Configuration) -> Color {
		configuration.isPressed ? Color(.Button.Secondary.Background.selected) : Color(.Button.Secondary.Background.normal)
	}
	
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(ButtonStyleGuide.defaultFont)
			.frame(width: ButtonStyleGuide.defaultWidth, height: ButtonStyleGuide.defaultHeight)
			.padding()
			.foregroundStyle(foregroundColor(for: configuration))
			.background{
				Capsule(style: .circular)
					.stroke(borderColor(for: configuration), lineWidth: ButtonStyleGuide.defaultBorderWidth)
					.background(content: {
						Capsule().fill(backgroundColor(for: configuration))
					})
			}
	}
}

extension ButtonStyle where Self == ButtonStyleSecondary {
	static var secondary: Self {
		return .init()
	}
}

