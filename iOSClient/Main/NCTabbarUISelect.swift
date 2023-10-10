//
//  NCTabbarUISelect.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/10/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

@objc protocol NCTabBarSelectDelegate: AnyObject {
    func unselect(animation: Bool)
}

class NCTabBarSelect: ObservableObject {

    var tabBarController: UITabBarController?
    var hostingController: UIViewController?
    open weak var delegate: NCTabBarSelectDelegate?

    @Published var count: Int = 0

    init(tabBarController: UITabBarController? = nil, delegate: NCTabBarSelectDelegate? = nil) {

        guard let tabBarController else { return }
        let hostingController = UIHostingController(rootView: TabBarSelectView(tabBarSelect: self))
        let height: CGFloat = tabBarController.tabBar.frame.height

        self.tabBarController = tabBarController
        self.hostingController = hostingController
        self.delegate = delegate

        tabBarController.tabBar.isHidden = true
        tabBarController.addChild(hostingController)
        tabBarController.view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.bottomAnchor.constraint(equalTo: tabBarController.view.bottomAnchor).isActive = true
        hostingController.view.rightAnchor.constraint(equalTo: tabBarController.view.rightAnchor).isActive = true
        hostingController.view.leftAnchor.constraint(equalTo: tabBarController.view.leftAnchor).isActive = true
        hostingController.view.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    func removeTabBar(animation: Bool) {

        hostingController?.view.removeFromSuperview()
        tabBarController?.tabBar.isHidden = false
    }
}

struct TabBarSelectView: View {

    @ObservedObject var tabBarSelect: NCTabBarSelect

    var body: some View {
        ZStack(alignment: .top) {
            Color(UIColor.systemBackground).ignoresSafeArea()
            VStack {
                Divider()
                Button("Unselect") {
                    tabBarSelect.delegate?.unselect(animation: true)
                }
                Text("Counter" + String(self.tabBarSelect.count))
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    TabBarSelectView(tabBarSelect: NCTabBarSelect())
}
