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
    
    var maxWidth: CGFloat? = nil
	
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
			.frame(maxWidth: maxWidth,
                   minHeight: CommonButtonConstants.defaultHeight)
            .padding([.leading, .trailing], 24)
			.foregroundStyle(foregroundColor(for: configuration))
			.background{
				Capsule(style: .circular)
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
    
    var maxWidth: CGFloat? = nil
	
	private func foregroundColor(for configuration: Configuration) -> Color {
		if isEnabled {
			return configuration.isPressed ? Color(.Button.Secondary.Text.selected) : Color(.Button.Secondary.Text.normal)
		}
		return Color(.Button.Secondary.Text.disabled)
	}
	
	private func borderColor(for configuration: Configuration) -> Color {
		isEnabled ? Color(.Button.Secondary.Border.normal) : Color(.Button.Secondary.Border.disabled)
	}
	
	private func backgroundColor(for configuration: Configuration) -> Color {
		configuration.isPressed ? Color(.Button.Secondary.Background.selected) : Color(.Button.Secondary.Background.normal)
	}
	
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(CommonButtonConstants.defaultFont)
			.frame(maxWidth: maxWidth,
                   minHeight: CommonButtonConstants.defaultHeight)
            .padding([.leading, .trailing], 24)
			.foregroundStyle(foregroundColor(for: configuration))
			.background{
				Capsule(style: .circular)
					.stroke(borderColor(for: configuration), lineWidth: CommonButtonConstants.defaultBorderWidth)
					.background(content: {
						Capsule().fill(backgroundColor(for: configuration))
					})
			}
            .makeAllButtonSpaceTappable()
	}
}

private extension View {
    func makeAllButtonSpaceTappable() -> some View {
        self.contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == ButtonStyleSecondary {
	static var secondary: Self {
		return .init()
	}
}

#Preview {
    VStack(spacing: 30) {
        VStack {
            Button {
            } label: {
                Text("Primary default state")
            }
            .buttonStyle(.primary)
            
            Button {
            } label: {
                Text("Primary disabled state")
            }
            .buttonStyle(.primary)
            .disabled(true)
            
            Spacer()
                .frame(height: 30)
            
            Button {
            } label: {
                Text("Secondary default state")
            }
            .buttonStyle(.secondary)
            
            Button {
            } label: {
                Text("Secondary disabled state")
            }
            .buttonStyle(.secondary)
            .disabled(true)
        }
        .frame(width: 300, height: 300)
        .background(Color(.AppBackground.main))
        .environment(\.colorScheme, .light)
        VStack {
            Button {
            } label: {
                Text("Primary default state")
            }
            .buttonStyle(.primary)
            
            Button {
            } label: {
                Text("Primary disabled state")
            }
            .buttonStyle(.primary)
            .disabled(true)
            
            Spacer()
                .frame(height: 30)
            
            Button {
            } label: {
                Text("Secondary default state")
            }
            .buttonStyle(.secondary)
            
            Button {
            } label: {
                Text("Secondary disabled state")
            }
            .buttonStyle(.secondary)
            .disabled(true)
        }
        .frame(width: 300, height: 300)
        .background(Color(.AppBackground.main))
        .environment(\.colorScheme, .dark)
    }
}
