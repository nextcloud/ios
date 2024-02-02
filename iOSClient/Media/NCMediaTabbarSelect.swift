//
//  NCMediaTabbarSelect.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/02/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import UIKit
import SwiftUI

protocol NCTabBarSelectDelegate: AnyObject {
    func unselect(tabBarSelect: NCMediaTabbarSelect)
    func delete(tabBarSelect: NCMediaTabbarSelect)
}

class NCMediaTabbarSelect: ObservableObject {

    var tabBarController: UITabBarController?
    var hostingController: UIViewController?
    open weak var delegate: NCTabBarSelectDelegate?

    @Published var selectCount: Int = 0

    init(tabBarController: UITabBarController? = nil, height: CGFloat, delegate: NCTabBarSelectDelegate? = nil) {

        guard let tabBarController else { return }
        let hostingController = UIHostingController(rootView: MediaTabBarSelectView(object: self))

        self.tabBarController = tabBarController
        self.hostingController = hostingController
        self.delegate = delegate

        tabBarController.tabBar.isHidden = true
        tabBarController.addChild(hostingController)
        tabBarController.view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.bottomAnchor.constraint(equalTo: tabBarController.view.bottomAnchor, constant: tabBarController.view.safeAreaInsets.bottom),
            hostingController.view.rightAnchor.constraint(equalTo: tabBarController.view.rightAnchor),
            hostingController.view.leftAnchor.constraint(equalTo: tabBarController.view.leftAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: height + tabBarController.view.safeAreaInsets.bottom)
        ])

        hostingController.view.backgroundColor = .clear
    }

    func removeTabBar() {

        hostingController?.view.removeFromSuperview()
        tabBarController?.tabBar.isHidden = false
    }
}

struct MediaTabBarSelectView: View {

    @ObservedObject var object: NCMediaTabbarSelect

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack {
                    Button("Unselect") {
                        object.delegate?.unselect(tabBarSelect: object)
                    }
                    Button("delete") {
                        object.delegate?.delete(tabBarSelect: object)
                    }.disabled(self.object.selectCount == 0)
                    Text("Counter" + String(self.object.selectCount))
                        .font(.system(size: 15))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }.onAppear {

            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .ignoresSafeArea(edges: .all)
            .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    MediaTabBarSelectView(object: NCMediaTabbarSelect(height: 100))
}
