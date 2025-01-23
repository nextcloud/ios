//
//  BurgerMenuView.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 28.07.2024.
//  Copyright © 2024 STRATO GmbH
//

import SwiftUI

private enum _Constants {
    static let font = Font.system(size: 16).weight(.medium)
    static let buttonPressedFont = font.weight(.semibold)
    static let spacingBetweenItems: CGFloat = 12
    static let buttonLeadingPadding: CGFloat = 12
}

struct BurgerMenuView: View {
    @ObservedObject var viewModel: BurgerMenuViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Color(.BurgerMenu.overlay)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.hideMenu()
                    }
                HStack(spacing: 0, content: {
                    VStack(alignment: .leading, spacing: _Constants.spacingBetweenItems) {
                        Image(.ionosEasyStorageLogo)
                            .resizable()
                            .renderingMode(.template)
                            .foregroundStyle(Color(.NavigationBar.logoTint))
                            .scaledToFit()
                            .padding(EdgeInsets(top: 24,
                                                leading: 0,
                                                bottom: 8,
                                                trailing: 0))
                            .frame(height: 54)
                        Button(action: {
                            viewModel.hideMenu()
                        }, label: {
                            HStack(spacing: 12) {
                                Image(.BurgerMenu.chevronLeft)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 10, height: 16)
                                Text(NSLocalizedString("_previous_", tableName: nil, bundle: Bundle.main, value: "Previous", comment: ""))
                                    .font(_Constants.font)
                            }
                            .foregroundStyle(Color(.BurgerMenu.buttonForeground))
                        })
                        .frame(height: 48)
                        if #available(iOS 16.4, *) {
                            BurgerMenuMainSectionView(viewModel: viewModel)
                                .scrollBounceBehavior(.basedOnSize)
                        } else {
                            BurgerMenuMainSectionView(viewModel: viewModel)
                        }
                    }
                    .padding(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                    .frame(width: min(width*0.75, 300), alignment: .leading)
                    .background(Color(.BurgerMenu.background))
                    .offset(x: viewModel.isVisible ? 0 : -width)
                })
            }
        }
        .opacity(viewModel.isVisible ? 1 : 0)
        .animation(.easeInOut(duration: viewModel.appearingAnimationIntervalInSec),
                   value: viewModel.isVisible)
    }
}

private struct BurgerMenuMainSectionView: View {
    @ObservedObject var viewModel: BurgerMenuViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: _Constants.spacingBetweenItems, content: {
                    BurgerMenuViewButton(image: .BurgerMenu.recent,
                                         title: NSLocalizedString("_recent_",
                                                                  comment: ""),
                                         action: {
                        viewModel.openRecent()
                    })
                    BurgerMenuViewButton(image: .BurgerMenu.offline,
                                         title: NSLocalizedString("_offline_",
                                                                  comment: ""),
                                         action: {
                        viewModel.openOffline()
                    })
                    BurgerMenuViewButton(image: .BurgerMenu.deleted,
                                         title: NSLocalizedString("_trash_view_",
                                                                  comment: ""),
                                         action: {
                        viewModel.openDeletedFiles()
                    })
                    Spacer()
                    BurgerMenuViewButton(image: .BurgerMenu.settings,
                                         title: NSLocalizedString("_settings_",
                                                                  comment: ""),
                                         action: {
                        viewModel.openSettings()
                    })
                    VStack(alignment: .leading, spacing: 0, content: {
                        HStack(spacing: 12, content: {
                            Image(.BurgerMenu.cloud)
                                .buttonIconStyled()
                            Text(NSLocalizedString("_storage_used_", tableName: nil, bundle: Bundle.main, value: "Storage used",
                                                   comment: ""))
                            .font(_Constants.font.weight(.semibold))
                        })
                        .frame(height: 48)
                        CustomProgressView(progress: viewModel.progressUsedSpace)
                        Spacer().frame(height: 8)
                        Text(viewModel.messageUsedSpace)
                            .font(.system(size: 16))
                    })
                    .foregroundStyle(Color(.BurgerMenu.buttonForeground))
                    .padding(EdgeInsets(top: 0, leading: _Constants.buttonLeadingPadding, bottom: 0, trailing: 0))
                })
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0))
                .frame(minHeight: geometry.size.height)
            }
        }
    }
}

private struct BurgerMenuViewButton: View {
    let image: ImageResource
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: {
            action()
        }, label: {
            HStack(spacing: 12) {
                Image(image)
                    .buttonIconStyled()
                Text(title)
                Spacer()
            }
            .makeAllButtonSpaceTappable()
            .foregroundStyle(Color(.BurgerMenu.buttonForeground))
            .frame(height: 48)
            .padding(EdgeInsets(top: 0, leading: _Constants.buttonLeadingPadding, bottom: 0, trailing: 0))
        })
        .buttonStyle(CustomBackgroundOnPressButtonStyle())
    }
}

private struct CustomBackgroundOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .font(configuration.isPressed ? _Constants.buttonPressedFont : _Constants.font)
            .background {
                if configuration.isPressed {
                    GeometryReader { geometry in
                        Color(.BurgerMenu.pressedButton)
                            .clipShape(RoundedRectangle(cornerRadius: geometry.size.height/2))
                    }
                } else {
                    EmptyView()
                }
            }
    }
}

private struct CustomProgressView: View {
    private let height: CGFloat = 8
    private let cornerRadius: CGFloat = 13
    private let blurRadius: CGFloat = 2
    let progress: Double
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.BurgerMenu.progressBarBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color(.BurgerMenu.commonShadow).opacity(0.6), 
                                    lineWidth: 1)
                            .frame(width: geometry.size.width+blurRadius,
                                   height: 2*geometry.size.height)
                            .blur(radius: blurRadius)
                            .offset(x: blurRadius/2,
                                    y: geometry.size.height/2)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            Color(NCBrandColor.shared.brandElement)
                .frame(width: geometry.size.width * progress + height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .offset(x: -height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: Color(.BurgerMenu.commonShadow).opacity(0.25),
                        radius: 2,
                        x: 0,
                        y: 1)
        }
        .frame(height: height)
    }
}

private extension Image {
    func buttonIconStyled() -> some View {
        self
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
    }
}

private extension View {
    func makeAllButtonSpaceTappable() -> some View {
        self.contentShape(Rectangle())
    }
}

#Preview {
    class BurgerMenuViewModelMock: BurgerMenuViewModel {
        override init(delegate: (any BurgerMenuViewModelDelegate)?,
                      controller: NCMainTabBarController?) {
            super.init(delegate: delegate, controller: nil)
            progressUsedSpace = 0.3
            messageUsedSpace = "62,5 MB of 607,21 GB used"
            isVisible = true
        }
    }
    
    struct CustomPreviewView: View {
        @StateObject var viewModel = BurgerMenuViewModelMock(delegate: nil, controller: nil)
        var body: some View {
            return NavigationView {
                BurgerMenuView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                viewModel.isVisible.toggle()
                            }, label: {
                                Image(systemName:
                                        "line.3.horizontal")
                            })
                        }
                    }
                    .navigationBarHidden(viewModel.isVisible)
             }
        }
    }
    
    return CustomPreviewView()
}
