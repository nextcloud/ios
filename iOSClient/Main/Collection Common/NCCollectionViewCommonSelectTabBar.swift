//
//  NCCollectionViewCommonSelectionTabBar.swift
//  Nextcloud
//
//  Created by Milen on 01.02.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import SwiftUI

protocol NCCollectionViewCommonSelectTabBarDelegate: AnyObject {
    func selectAll()
    func delete()
    func move()
    func share()
    func saveAsAvailableOffline(isAnyOffline: Bool)
    func lock(isAnyLocked: Bool)
}

class NCCollectionViewCommonSelectTabBar: ObservableObject {
    var controller: NCMainTabBarController?
    var hostingController: UIViewController?
    open weak var delegate: NCCollectionViewCommonSelectTabBarDelegate?

    @Published var isAnyOffline = false
    @Published var canSetAsOffline = false
    @Published var isAnyDirectory = false
    @Published var isAllDirectory = false
    @Published var isAnyLocked = false
    @Published var canUnlock = true
    @Published var enableLock = false
    @Published var isSelectedEmpty = true

    init(controller: NCMainTabBarController? = nil, delegate: NCCollectionViewCommonSelectTabBarDelegate? = nil) {
        let rootView = NCCollectionViewCommonSelectTabBarView(tabBarSelect: self)
        hostingController = UIHostingController(rootView: rootView)

        self.controller = controller
        self.delegate = delegate

        guard let controller, let hostingController else { return }

        controller.view.addSubview(hostingController.view)

        hostingController.view.frame = controller.tabBar.frame
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.view.backgroundColor = .clear
        hostingController.view.isHidden = true
    }

    func show() {
        guard let controller, let hostingController else { return }

        controller.tabBar.isHidden = true
        if hostingController.view.isHidden {
            hostingController.view.isHidden = false
            hostingController.view.transform = .init(translationX: 0, y: hostingController.view.frame.height)
            UIView.animate(withDuration: 0.2) {
                hostingController.view.transform = .init(translationX: 0, y: 0)
            }
        }
    }

    func hide() {
        guard let controller, let hostingController else { return }

        hostingController.view.isHidden = true
        controller.tabBar.isHidden = false
    }

    func isHidden() -> Bool {
        guard let hostingController else { return false }
        return hostingController.view.isHidden
    }

    func update(selectOcId: [String], metadatas: [tableMetadata]? = nil, userId: String? = nil) {
        if let metadatas {

            isAnyOffline = false
            canSetAsOffline = true
            isAnyDirectory = false
            isAllDirectory = true
            isAnyLocked = false
            canUnlock = true

            for metadata in metadatas {
                if metadata.directory {
                    isAnyDirectory = true
                } else {
                    isAllDirectory = false
                }

                if !metadata.canSetAsAvailableOffline {
                    canSetAsOffline = false
                }

                if metadata.lock {
                    isAnyLocked = true
                    if metadata.lockOwner != userId {
                        canUnlock = false
                    }
                }

                guard !isAnyOffline else { continue }

                if metadata.directory,
                   let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl + "/" + metadata.fileName)) {
                    isAnyOffline = directory.offline
                } else if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                    isAnyOffline = localFile.offline
                } // else: file is not offline, continue
            }
            enableLock = !isAnyDirectory && canUnlock && !NCGlobal.shared.capabilityFilesLockVersion.isEmpty
        }
        isSelectedEmpty = selectOcId.isEmpty
    }
}

struct NCCollectionViewCommonSelectTabBarView: View {
    @ObservedObject var tabBarSelect: NCCollectionViewCommonSelectTabBar
    @Environment(\.verticalSizeClass) var sizeClass

    var body: some View {
        VStack {
            Spacer().frame(height: sizeClass == .compact ? 5 : 10)

            HStack {
                Button {
                    tabBarSelect.delegate?.share()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(Font.system(.body).weight(.light))
                        .imageScale(sizeClass == .compact ? .medium : .large)
                }
                .tint(Color(NCBrandColor.shared.iconImageColor))
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty || tabBarSelect.isAllDirectory)

                Button {
                    tabBarSelect.delegate?.move()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(Font.system(.body).weight(.light))
                        .imageScale(sizeClass == .compact ? .medium : .large)
                }
                .tint(Color(NCBrandColor.shared.iconImageColor))
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty)

                Button {
                    tabBarSelect.delegate?.delete()
                } label: {
                    Image(systemName: "trash")
                        .font(Font.system(.body).weight(.light))
                        .imageScale(sizeClass == .compact ? .medium : .large)
                }
                .tint(.red)
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty)

                Menu {
                    Button(action: {
                        tabBarSelect.delegate?.saveAsAvailableOffline(isAnyOffline: tabBarSelect.isAnyOffline)
                    }, label: {
                        Label(NSLocalizedString(tabBarSelect.isAnyOffline ? "_remove_available_offline_" : "_set_available_offline_", comment: ""), systemImage: tabBarSelect.isAnyOffline ? "icloud.slash" : "icloud.and.arrow.down")

                        if !tabBarSelect.canSetAsOffline && !tabBarSelect.isAnyOffline {
                            Text(NSLocalizedString("_e2ee_set_as_offline_", comment: ""))
                        }
                    })
                    .disabled(!tabBarSelect.isAnyOffline && (!tabBarSelect.canSetAsOffline || tabBarSelect.isSelectedEmpty))

                    Button(action: {
                        tabBarSelect.delegate?.lock(isAnyLocked: tabBarSelect.isAnyLocked)
                    }, label: {
                        Label(NSLocalizedString(tabBarSelect.isAnyLocked ? "_unlock_" : "_lock_", comment: ""), systemImage: tabBarSelect.isAnyLocked ? "lock.open" : "lock")

                        if !tabBarSelect.enableLock {
                            Text(NSLocalizedString("_lock_no_permissions_selected_", comment: ""))
                        }
                    })
                    .disabled(!tabBarSelect.enableLock || tabBarSelect.isSelectedEmpty)

                    Button(action: {
                        tabBarSelect.delegate?.selectAll()
                    }, label: {
                        Label(NSLocalizedString("_select_all_", comment: ""), systemImage: "checkmark")
                    })
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(Font.system(.body).weight(.light))
                        .imageScale(sizeClass == .compact ? .medium : .large)
                }
                .tint(Color(NCBrandColor.shared.iconImageColor))
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial)
        .overlay(Rectangle().frame(width: nil, height: 0.5, alignment: .top).foregroundColor(Color(UIColor.separator)), alignment: .top)
    }
}

#Preview {
    NCCollectionViewCommonSelectTabBarView(tabBarSelect: NCCollectionViewCommonSelectTabBar())
}
