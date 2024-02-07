//
//  NCCollectionViewCommonSelectionTabBar.swift
//  Nextcloud
//
//  Created by Milen on 01.02.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import SwiftUI

protocol NCCollectionViewCommonSelectTabBarDelegate: AnyObject {
    func selectAll()
    func delete(selectedMetadatas: [tableMetadata])
    func move(selectedMetadatas: [tableMetadata])
    func share(selectedMetadatas: [tableMetadata])
    func saveAsAvailableOffline(selectedMetadatas: [tableMetadata], isAnyOffline: Bool)
    func lock(selectedMetadatas: [tableMetadata], isAnyLocked: Bool)
}

class NCCollectionViewCommonSelectTabBar: NCSelectableViewTabBar, ObservableObject {
    private var tabBarController: UITabBarController?
    private var hostingController: UIViewController?
    open weak var delegate: NCCollectionViewCommonSelectTabBarDelegate?

    var selectedMetadatas: [tableMetadata] = []

    @Published var isAnyOffline = false
    @Published var isAnyDirectory = false
    @Published var isAllDirectory = false
    @Published var isAnyLocked = false
    @Published var canUnlock = true
    @Published var enableLock = false
    @Published var isSelectedEmpty = true

    init(tabBarController: UITabBarController? = nil, delegate: NCCollectionViewCommonSelectTabBarDelegate? = nil) {
        let rootView = NCCollectionViewCommonSelectTabBarView(tabBarSelect: self)
        hostingController = UIHostingController(rootView: rootView)

        self.tabBarController = tabBarController
        self.delegate = delegate

        guard let tabBarController, let hostingController else { return }

        tabBarController.addChild(hostingController)
        tabBarController.view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.rightAnchor.constraint(equalTo: tabBarController.tabBar.rightAnchor),
            hostingController.view.leftAnchor.constraint(equalTo: tabBarController.tabBar.leftAnchor),
            hostingController.view.topAnchor.constraint(equalTo: tabBarController.tabBar.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: tabBarController.tabBar.bottomAnchor)
        ])

        hostingController.view.backgroundColor = .clear
        hostingController.view.isHidden = true
    }

    func show() {
        guard let tabBarController, let hostingController else { return }

        tabBarController.tabBar.isHidden = true

        if hostingController.view.isHidden {
            hostingController.view.isHidden = false

            hostingController.view.transform = .init(translationX: 0, y: hostingController.view.frame.height)

            UIView.animate(withDuration: 0.2) {
                hostingController.view.transform = .init(translationX: 0, y: 0)
            }
        }
    }

    func hide() {
        guard let tabBarController, let hostingController else { return }

        hostingController.view.isHidden = true
        tabBarController.tabBar.isHidden = false
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
                    tabBarSelect.delegate?.share(selectedMetadatas: tabBarSelect.selectedMetadatas)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .imageScale(sizeClass == .compact ? .medium : .large)

                }
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty || tabBarSelect.isAllDirectory)

                Button {
                    tabBarSelect.delegate?.move(selectedMetadatas: tabBarSelect.selectedMetadatas)
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .imageScale(sizeClass == .compact ? .medium : .large)
                }
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty)

                Button {
                    tabBarSelect.delegate?.delete(selectedMetadatas: tabBarSelect.selectedMetadatas)
                } label: {
                    Image(systemName: "trash")
                        .imageScale(sizeClass == .compact ? .medium : .large)
                }
                .tint(.red)
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty)

                Menu {
                    Button(action: {
                        tabBarSelect.delegate?.saveAsAvailableOffline(selectedMetadatas: tabBarSelect.selectedMetadatas, isAnyOffline: tabBarSelect.isAnyOffline)
                    }, label: {
                        Label(NSLocalizedString(tabBarSelect.isAnyOffline ? "_remove_available_offline_" : "_set_available_offline_", comment: ""), systemImage: tabBarSelect.isAnyOffline ? "icloud.slash" : "icloud.and.arrow.down")
                    })
                    .disabled(tabBarSelect.isSelectedEmpty)

                    Button(action: {
                        tabBarSelect.delegate?.lock(selectedMetadatas: tabBarSelect.selectedMetadatas, isAnyLocked: tabBarSelect.isAnyLocked)
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
                        .imageScale(sizeClass == .compact ? .medium : .large)
                }
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
