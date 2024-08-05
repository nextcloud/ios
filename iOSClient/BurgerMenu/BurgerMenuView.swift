//
//  BurgerMenuView.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 28.07.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

struct BurgerMenuView: View {
    @ObservedObject var viewModel: BurgerMenuViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Button(action: {
                    viewModel.hideMenu()
                }, label: {
                    Color.gray.opacity(0.2)
                })
                .ignoresSafeArea()
                HStack(spacing: 0, content: {
                    VStack(alignment: .leading, spacing: 28) {
                        Button(action: {
                            viewModel.hideMenu()
                        }, label: {
                            HStack {
                                Image(systemName: "chevron.backward")
                                Text(NSLocalizedString("_back_", comment: ""))
                            }
                            .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                        })
                        BurgerMenuViewButton(image: Image(systemName: "clock"),
                                             title: NSLocalizedString("_recent_", 
                                                                      comment: ""),
                                             action: {
                            viewModel.openRecent()
                        })
                        BurgerMenuViewButton(image: Image(systemName: "icloud.slash"),
                                             title: NSLocalizedString("_offline_", 
                                                                      comment: ""),
                                             action: {
                            viewModel.openOffline()
                        })
                        BurgerMenuViewButton(image: Image(systemName: "trash"),
                                             title: NSLocalizedString("_trash_view_", 
                                                                      comment: ""),
                                             action: {
                            viewModel.openDeletedFiles()
                        })
                        Spacer()
                        BurgerMenuViewButton(image: Image(systemName: "gear"),
                                             title: NSLocalizedString("_settings_",
                                                                      comment: ""),
                                             action: {
                            viewModel.openSettings()
                        })
                        VStack(alignment: .leading, content: {
                            HStack(content: {
                                Image(systemName: "cloud.fill")
                                Text(NSLocalizedString("_used_space_",
                                                       comment: ""))
                            })
                            ProgressView(value: viewModel.progressUsedSpace, total: 1)
                                .tint(viewModel.brandColor)
                            Text(viewModel.messageUsedSpace)
                        })
                        .padding(EdgeInsets(top: 0,
                                            leading: 7,
                                            bottom: 0,
                                            trailing: 0))
                        .foregroundStyle(viewModel.brandColor)
                        Spacer()
                            .frame(height: 50)
                    }
                    .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    .frame(width: width*0.75, alignment: .leading)
                    .background(Color(UIColor.systemBackground))
                    .environmentObject(viewModel)
                    .offset(x: viewModel.isVisible ? 0 : -width)
                })
            }
        }
        .opacity(viewModel.isVisible ? 1 : 0)
        .animation(.easeInOut(duration: viewModel.appearingAnimationIntervalInSec),
                   value: viewModel.isVisible)
    }
}

private struct BurgerMenuViewButton: View {
    @EnvironmentObject private var viewModel: BurgerMenuViewModel
    let image: Image
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: {
            action()
        }, label: {
            HStack {
                image
                Text(title)
            }
            .foregroundStyle(viewModel.brandColor)
        })
    }
}

#Preview {
    class BurgerMenuViewModelMock: BurgerMenuViewModel {
        override init(delegate: (any BurgerMenuViewModelDelegate)?) {
            super.init(delegate: delegate)
            progressUsedSpace = 0.5
            messageUsedSpace = "You are using 62,5 MB of 607,21 GB"
        }
    }
    let viewModel = BurgerMenuViewModelMock(delegate: nil)
    viewModel.brandColor = .red
    return BurgerMenuView(viewModel: viewModel)
}
