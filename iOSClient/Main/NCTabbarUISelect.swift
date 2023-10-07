//
//  NCTabbarUISelect.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/10/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

@objc protocol NCTabBarSelectDelegate: AnyObject {
    func unselect()
}

class NCTabBarSelect: ObservableObject {

    var tabBarController: UITabBarController?
    var hostingController: UIViewController?
    open weak var delegate: NCTabBarSelectDelegate?

    public func addTabBar(tabBarController: UITabBarController?, delegate: UIViewController?) {

        guard let tabBarController else { return }
        let hostingController = UIHostingController(rootView: TabBarSelectView(tabBarSelect: self))
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

    @ObservedObject var tabBarSelect: NCTabBarSelect

    var body: some View {
        VStack(alignment: .leading) {
            Button("Unselect") {
                tabBarSelect.delegate?.unselect()
                tabBarSelect.removeTabBar()
            }
        }
    }
}

#Preview {
    TabBarSelectView(tabBarSelect: NCTabBarSelect())
}

/*
struct TabBarSelectView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarSelectView(tabBarSelect: NCTabBarSelect())
    }
}
*/
