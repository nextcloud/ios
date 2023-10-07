//
//  NCTabbarUI.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/10/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

class NCTabbarUI: NSObject {

    var tabBarController: UITabBarController?
    var controller: UIViewController?

    public func addTabBar(tabBarController: UITabBarController?) {

        guard let tabBarController else { return }
        let controller = UIHostingController(rootView: TabBarSelect())
        let height: CGFloat = tabBarController.tabBar.frame.height

        self.tabBarController = tabBarController
        self.controller = controller

        tabBarController.tabBar.isHidden = true
        tabBarController.addChild(controller)
        tabBarController.view.addSubview(controller.view)

        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.bottomAnchor.constraint(equalTo: tabBarController.view.bottomAnchor).isActive = true
        controller.view.rightAnchor.constraint(equalTo: tabBarController.view.rightAnchor).isActive = true
        controller.view.leftAnchor.constraint(equalTo: tabBarController.view.leftAnchor).isActive = true
        controller.view.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    func removeTabBar() {

        controller?.view.removeFromSuperview()
        tabBarController?.tabBar.isHidden = false
    }
}

struct TabBarSelect: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    TabBarSelect()
}
