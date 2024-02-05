//
//  NCTrashSelectTabBar.swift
//  Nextcloud
//
//  Created by Milen on 05.02.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import SwiftUI

protocol NCTrashSelectTabBarDelegate: AnyObject {
    func selectAll()
    func recover()
    func delete()
}

class NCTrashSelectTabBar: NCSelectableViewTabBar, ObservableObject {
    private var tabBarController: UITabBarController?
    private var hostingController: UIViewController?
    open weak var delegate: NCTrashSelectTabBarDelegate?

    var selectedMetadatas: [tableMetadata] = []

    @Published var isAnyOffline = false
    @Published var isAnyDirectory = false
    @Published var isAllDirectory = false
    @Published var isAnyLocked = false
    @Published var canUnlock = true
    @Published var enableLock = false
    @Published var isSelectedEmpty = true

    init(tabBarController: UITabBarController? = nil, height: CGFloat = 83, delegate: NCTrashSelectTabBarDelegate? = nil) {
        guard let tabBarController else { return }

        let hostingController = UIHostingController(rootView: NCTrashSelectTabBarView(height: height, tabBarSelect: self))

        self.tabBarController = tabBarController
        self.hostingController = hostingController
        self.delegate = delegate

        tabBarController.addChild(hostingController)
        tabBarController.view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.bottomAnchor.constraint(equalTo: tabBarController.view.bottomAnchor).isActive = true
        hostingController.view.rightAnchor.constraint(equalTo: tabBarController.view.rightAnchor).isActive = true
        hostingController.view.leftAnchor.constraint(equalTo: tabBarController.view.leftAnchor).isActive = true
        hostingController.view.heightAnchor.constraint(equalToConstant: height).isActive = true
        hostingController.view.backgroundColor = .clear

        hostingController.view.isHidden = true
    }

    func show(animation: Bool) {
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

    func hide(animation: Bool) {
        guard let tabBarController, let hostingController else { return }

        hostingController.view.isHidden = true
        tabBarController.tabBar.isHidden = false
    }
}

struct NCTrashSelectTabBarView: View {
    let height: CGFloat
    @ObservedObject var tabBarSelect: NCTrashSelectTabBar

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button {
                    tabBarSelect.delegate?.recover()
                } label: {
                    Image(systemName: "arrow.circlepath")
                }
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty || tabBarSelect.isAllDirectory)

                Button {
                    tabBarSelect.delegate?.delete()
                } label: {
                    Image(systemName: "trash").tint(.red)
                }
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty || tabBarSelect.isAllDirectory)

                Button {                                   tabBarSelect.delegate?.selectAll()
                } label: {
                    Image(systemName: "checkmark")
                }
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty || tabBarSelect.isAllDirectory)
            }

            Spacer().frame(height: 20)
        }
        .frame(height: height)
        .background(.thinMaterial)
        .overlay(Rectangle().frame(width: nil, height: 0.5, alignment: .top).foregroundColor(Color(UIColor.separator)), alignment: .top)
    }
}

#Preview {
    NCTrashSelectTabBarView(height: 83, tabBarSelect: NCTrashSelectTabBar())
}

