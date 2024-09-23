//
//  ButtonStyleGuide.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 13.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

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
			.font(CommonButtonConstants.defaultFont)
			.frame(width: CommonButtonConstants.defaultWidth, height: CommonButtonConstants.defaultHeight)
			.padding()
			.foregroundStyle(foregroundColor(for: configuration))
			.background{
				Capsule(style: .continuous)
					.stroke(backgroundColor(for: configuration), lineWidth: CommonButtonConstants.defaultBorderWidth)
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
			.font(CommonButtonConstants.defaultFont)
			.frame(width: CommonButtonConstants.defaultWidth, height: CommonButtonConstants.defaultHeight)
			.padding()
			.foregroundStyle(foregroundColor(for: configuration))
			.background{
				Capsule(style: .continuous)
					.stroke(borderColor(for: configuration), lineWidth: CommonButtonConstants.defaultBorderWidth)
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

