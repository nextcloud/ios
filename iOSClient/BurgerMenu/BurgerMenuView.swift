//
//  BurgerMenuView.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 28.07.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

private enum _Constants {
    static let font = Font.system(size: 18)
    static let spacingBetweenItems: CGFloat = 17
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
                        Button(action: {
                            viewModel.hideMenu()
                        }, label: {
                            HStack(spacing: 12) {
                                Image(systemName: "chevron.left")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 20)
                                Text(NSLocalizedString("_back_", comment: ""))
                                    .font(_Constants.font)
                            }
                            .foregroundStyle(Color(.BurgerMenu.backButton))
                        })
                        .padding(EdgeInsets(top: 3, leading: 2.5, bottom: 3, trailing: 2.5))
                        if #available(iOS 16.4, *) {
                            BurgerMenuMainSectionView(viewModel: viewModel)
                                .scrollBounceBehavior(.basedOnSize)
                        } else {
                            BurgerMenuMainSectionView(viewModel: viewModel)
                        }
                    }
                    .padding(EdgeInsets(top: 0, leading: 19, bottom: 0, trailing: 28))
                    .frame(width: width*0.85, alignment: .leading)
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
                            Text(NSLocalizedString("_used_space_",
                                                   comment: ""))
                            .font(_Constants.font.weight(.semibold))
                        })
                        Spacer().frame(height: 11)
                        CustomProgressView(progress: viewModel.progressUsedSpace)
                        Spacer().frame(height: 16)
                        Text(viewModel.messageUsedSpace)
                            .font(_Constants.font)
                    })
                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                    .foregroundStyle(Color(.BurgerMenu.buttonForeground))
                })
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 60, trailing: 0))
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
            HStack(spacing: 13) {
                Image(image)
                    .buttonIconStyled()
                Text(title)
                    .font(_Constants.font)
                Spacer()
            }
            .makeAllButtonSpaceTappable()
            .foregroundStyle(Color(.BurgerMenu.buttonForeground))
            .frame(height: 51)
            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
        })
        .buttonStyle(CustomBackgroundOnPressButtonStyle())
    }
}

private struct CustomProgressView: View {
    private let height: CGFloat = 9
    let progress: Double
    var body: some View {
        GeometryReader { geometry in
            Color(.BurgerMenu.progressBarBackground)
            Color(NCBrandColor.shared.brandElement)
                .frame(width: geometry.size.width * progress)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height/2))
    }
}

private extension Image {
    func buttonIconStyled() -> some View {
        self
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 28, height: 28)
    }
}

private struct CustomBackgroundOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if configuration.isPressed {
            configuration
                .label
                .background {
                    GeometryReader { geometry in
                        Color(.BurgerMenu.pressedButton)
                            .clipShape(RoundedRectangle(cornerRadius: geometry.size.height/2))
                    }
                }
        } else {
            configuration.label
        }
    }
}

private extension View {
    func makeAllButtonSpaceTappable() -> some View {
        self.contentShape(Rectangle())
    }
}

#Preview {
    class BurgerMenuViewModelMock: BurgerMenuViewModel {
        override init(delegate: (any BurgerMenuViewModelDelegate)?) {
            super.init(delegate: delegate)
            progressUsedSpace = 0.005
            messageUsedSpace = "You are using 62,5 MB of 607,21 GB"
            isVisible = true
        }
    }
    
    struct CustomPreviewView: View {
        @StateObject var viewModel = BurgerMenuViewModelMock(delegate: nil)
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
