// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI
import NextcloudKit

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
    @Published var metadatas: [tableMetadata] = []

    init(controller: NCMainTabBarController? = nil, viewController: UIViewController, delegate: NCCollectionViewCommonSelectTabBarDelegate? = nil) {
        guard let controller else {
            return
        }
        let rootView = NCCollectionViewCommonSelectTabBarView(tabBarSelect: self)
        let bottomAreaInsets: CGFloat = controller.tabBar.safeAreaInsets.bottom == 0 ? 34 : 0
        let height = controller.tabBar.frame.height + bottomAreaInsets
        hostingController = UIHostingController(rootView: rootView)
        guard let hostingController else {
            return
        }

        self.controller = controller
        self.delegate = delegate

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        hostingController.view.isHidden = true

        viewController.view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: height)
        ])
    }

    func show() {
        guard let controller,
              let hostingController else {
            return
        }

        controller.hide()

        if hostingController.view.isHidden {
            hostingController.view.isHidden = false
            hostingController.view.transform = .init(translationX: 0, y: hostingController.view.frame.height)
            UIView.animate(withDuration: 0.3) {
                hostingController.view.transform = .identity
            }
        }
    }

    func hide() {
        guard let controller,
              let hostingController else {
            return
        }

        hostingController.view.isHidden = true
        controller.show()
    }

    func update(fileSelect: [String], metadatas: [tableMetadata]? = nil, userId: String? = nil) {
        if let metadatas {
            isAnyOffline = false
            canSetAsOffline = true
            isAnyDirectory = false
            isAllDirectory = true
            isAnyLocked = false
            canUnlock = true
            self.metadatas = metadatas

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
                   let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@",
                                                                                                    metadata.account,
                                                                                                    metadata.serverUrlFileName)) {
                    isAnyOffline = directory.offline
                } else if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                    isAnyOffline = localFile.offline
                } // else: file is not offline, continue
            }
            let capabilities = NCNetworking.shared.capabilities[controller?.account ?? ""] ?? NKCapabilities.Capabilities()
            enableLock = !isAnyDirectory && canUnlock && !capabilities.filesLockVersion.isEmpty
        }
        self.isSelectedEmpty = fileSelect.isEmpty
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
    NCCollectionViewCommonSelectTabBarView(tabBarSelect: NCCollectionViewCommonSelectTabBar(controller: nil, viewController: UIViewController(), delegate: nil))
}
