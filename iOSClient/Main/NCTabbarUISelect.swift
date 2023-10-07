//
//  NCTabbarUISelect.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/10/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

class NCTabBarSelect: NSObject {

    var tabBarController: UITabBarController?
    var hostingController: UIViewController?

    public func addTabBar(tabBarController: UITabBarController?) {

        guard let tabBarController else { return }
        let hostingController = UIHostingController(rootView: TabBarSelectView())
        let height: CGFloat = tabBarController.tabBar.frame.height

        self.tabBarController = tabBarController
        self.hostingController = hostingController

        tabBarController.tabBar.isHidden = true
        tabBarController.addChild(hostingController)
        tabBarController.view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.bottomAnchor.constraint(equalTo: tabBarController.view.bottomAnchor).isActive = true
        hostingController.view.rightAnchor.constraint(equalTo: tabBarController.view.rightAnchor).isActive = true
        hostingController.view.leftAnchor.constraint(equalTo: tabBarController.view.leftAnchor).isActive = true
        hostingController.view.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    func removeTabBar() {

        hostingController?.view.removeFromSuperview()
        tabBarController?.tabBar.isHidden = false
    }
}

struct TabBarSelectView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    TabBarSelectView()
}
