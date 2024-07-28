//
//  BurgerMenuView.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 28.07.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

protocol BurgerMenuViewDelegate {
    func moveBack()
    func openRecent()
    func openOffline()
    func openDeletedFiles()
    func openSettings()
}

struct BurgerMenuView: View {
    let delegate: BurgerMenuViewDelegate?
    fileprivate var usedAndFreeSpaceProvider: UsedAndFreeSpaceProvider
    @State var progressUsedSpace: Double = 0
    @State var messageUsedSpace: String = ""
    
    init(delegate: BurgerMenuViewDelegate) {
        self.delegate = delegate
        self.usedAndFreeSpaceProvider = UsedAndFreeSpaceProvider()
    }
    
    fileprivate init(delegate: BurgerMenuViewDelegate?, usedAndFreeSpaceProvider: UsedAndFreeSpaceProvider) {
        self.delegate = delegate
        self.usedAndFreeSpaceProvider = usedAndFreeSpaceProvider
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            HStack(spacing: 0, content: {
                VStack(alignment: .leading, spacing: 28) {
                    Button(action: {
                        delegate?.moveBack()
                    }, label: {
                        HStack {
                            Image(systemName: "chevron.backward")
                            Text(NSLocalizedString("_back_", comment: ""))
                        }
                        .foregroundStyle(Color(UIColor.label))
                    })
                    BurgerMenuViewButton(image: Image(systemName: "clock"),
                                         title: NSLocalizedString("_recent_", 
                                                                  comment: ""),
                                         action: {
                        delegate?.openRecent()
                    })
                    BurgerMenuViewButton(image: Image(systemName: "icloud.slash"),
                                         title: NSLocalizedString("_offline_", 
                                                                  comment: ""),
                                         action: {
                        delegate?.openOffline()
                    })
                    BurgerMenuViewButton(image: Image(systemName: "trash"),
                                         title: NSLocalizedString("_trash_view_", 
                                                                  comment: ""),
                                         action: {
                        delegate?.openDeletedFiles()
                    })
                    Spacer()
                    BurgerMenuViewButton(image: Image(systemName: "gear"),
                                         title: NSLocalizedString("_settings_",
                                                                  comment: ""),
                                         action: {
                        delegate?.openSettings()
                    })
                    VStack(alignment: .leading, content: {
                        HStack(content: {
                            Image(systemName: "cloud.fill")
                            Text(NSLocalizedString("_used_space_",
                                                   comment: ""))
                        })
                        ProgressView(value: progressUsedSpace, total: 1)
                            .tint(Color(NCBrandColor.shared.brandElement))
                        Text(messageUsedSpace)
                    })
                    .padding(EdgeInsets(top: 0,
                                        leading: 7,
                                        bottom: 0,
                                        trailing: 0))
                    .foregroundStyle(Color(NCBrandColor.shared.brandElement))
                    Spacer()
                        .frame(height: 50)
                }
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                .frame(width: width*0.75, alignment: .leading)
                .background(Color(UIColor.systemBackground))
                Button(action: {
                    delegate?.moveBack()
                }, label: {
                    Color.gray.opacity(0.5)
                })
            })
        }
        .onAppear(perform: {
            (progressUsedSpace, messageUsedSpace) = usedAndFreeSpaceProvider.provide()
        })
    }
}

private struct BurgerMenuViewButton: View {
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
            .foregroundStyle(Color(NCBrandColor.shared.brandElement))
        })
    }
}

private class UsedAndFreeSpaceProvider {
    func provide() -> (progress: Double, messageUsed: String) {
        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            var progressQuota: Double = 0
            if activeAccount.quotaRelative > 0 {
                progressQuota = activeAccount.quotaRelative/100.0
            }

            let utilityFileSystem = NCUtilityFileSystem()
            var quota = ""
            switch activeAccount.quotaTotal {
            case -1:
                quota = "0"
            case -2:
                quota = NSLocalizedString("_quota_space_unknown_", comment: "")
            case -3:
                quota = NSLocalizedString("_quota_space_unlimited_", comment: "")
            default:
                quota = utilityFileSystem.transformedSize(activeAccount.quotaTotal)
            }

            let quotaUsed: String = utilityFileSystem.transformedSize(activeAccount.quotaUsed)

            let messageUsed = String.localizedStringWithFormat(NSLocalizedString("_quota_using_", comment: ""), quotaUsed, quota)
            return (progressQuota, messageUsed)
        }
        return (0, "")
    }
}

#Preview {
    class UsedAndFreeSpaceProviderMock: UsedAndFreeSpaceProvider {
        override func provide() -> (progress: Double, messageUsed: String) {
            return (0.5, "You are using 62,5 MB of 607,21 GB")
        }
    }
    return BurgerMenuView(delegate: nil, usedAndFreeSpaceProvider: UsedAndFreeSpaceProviderMock())
}
