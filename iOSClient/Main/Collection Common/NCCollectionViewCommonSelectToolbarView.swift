//
//  File.swift
//  Nextcloud
//
//  Created by Andrey Gubarev on 03.09.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//


import SwiftUI

struct NCCollectionViewCommonSelectToolbarView: View {
    @ObservedObject var tabBarSelect: NCCollectionViewCommonSelectToolbar
    @Environment(\.verticalSizeClass) var sizeClass

    var body: some View {
        GeometryReader { geometry in
            let isWideScreen = geometry.size.width > 460
            let eightyPercentOfWidth = geometry.size.width * 0.85
            VStack {
                Spacer().frame(height: 10)

                HStack(alignment: .top) {
                    TabButton(
                        action: {tabBarSelect.delegate?.share()},
                        image: .SelectTabBar.copy,
                        label: "_share_",
                        isDisabled: tabBarSelect.isSelectedEmpty || tabBarSelect.isAllDirectory,
                        isOneRowStyle: isWideScreen
                    )
                    TabButton(
                        action: {tabBarSelect.delegate?.move()},
                        image: .SelectTabBar.share,
                        label: "_move_or_copy_",
                        isDisabled: tabBarSelect.isSelectedEmpty,
                        isOneRowStyle: isWideScreen
                    )
                    TabButton(
                        action: {tabBarSelect.delegate?.delete()},
                        image: .SelectTabBar.delete,
                        label: "_delete_",
                        isDisabled: tabBarSelect.isSelectedEmpty,
                        isOneRowStyle: isWideScreen
                    )
                    TabButton(
                        action: {tabBarSelect.delegate?.saveAsAvailableOffline(isAnyOffline: tabBarSelect.isAnyOffline)},
                        image: .SelectTabBar.download,
                        label: "_download_",
                        isDisabled: !tabBarSelect.isAnyOffline && (!tabBarSelect.canSetAsOffline || tabBarSelect.isSelectedEmpty),
                        isOneRowStyle: isWideScreen
                    )
                    TabButton(
                        action: {tabBarSelect.delegate?.lock(isAnyLocked: tabBarSelect.isAnyLocked)},
                        image: (tabBarSelect.isAnyLocked ? .SelectTabBar.unlock : .SelectTabBar.lock),
                        label: tabBarSelect.isAnyLocked ? "_unlock_" : "_lock_",
                        isDisabled: !tabBarSelect.enableLock || tabBarSelect.isSelectedEmpty,
                        isOneRowStyle: isWideScreen
                    )
                }
                .frame(maxWidth: isWideScreen ? eightyPercentOfWidth : .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.thinMaterial)
        }
    }
}

private struct TabButton: View {
    let action: (() -> Void)?
    let image: ImageResource
    let label: String
    let isDisabled: Bool
    let isOneRowStyle: Bool
    
    var body: some View {
        Button(action: {
            action?()
        }, label: {
            if isOneRowStyle {
                HStack {
                    IconWithText(image: image, label: label)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack {
                    IconWithText(image: image, label: label)
                }
                .frame(maxWidth: .infinity)
            }
        })
        .frame(maxWidth: .infinity)
        .buttonStyle(CustomBackgroundOnPressButtonStyle(isDisabled: isDisabled))
        .disabled(isDisabled)
    }
}

private struct IconWithText: View {
    @Environment(\.verticalSizeClass) var sizeClass
    var image: ImageResource
    var label: String
    
    var body: some View {
        var iconWidth = CGFloat( sizeClass == .compact ? 28 : 34)
        var iconHeight = iconWidth - 10
        Image(image)
            .resizable()
            .font(Font.system(.body).weight(.light))
            .scaledToFit()
            .frame(width: iconWidth, height: iconHeight)
        Text(NSLocalizedString(label, comment: ""))
            .font(.system(size: 11))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .tint(Color(NCBrandColor.shared.textColor))
    }
}

private struct CustomBackgroundOnPressButtonStyle: ButtonStyle {
    var isDisabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        if isDisabled {
            configuration.label.foregroundColor(Color(NCBrandColor.shared.iconImageColor2))
        } else if configuration.isPressed {
            configuration.label.foregroundColor(Color(NCBrandColor.shared.iconImageColor))
        } else {
            configuration.label.foregroundColor(Color(.SelectTabbar.buttonForeground))
        }
    }
}

#Preview {
    NCCollectionViewCommonSelectToolbarView(tabBarSelect: NCCollectionViewCommonSelectToolbar())
}

