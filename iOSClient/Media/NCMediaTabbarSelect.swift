//
//  NCMediaTabbarSelect.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/02/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

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
        let hostingController = UIHostingController(rootView: MediaTabBarSelectView(tabBarSelect: self))

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

    func removeTabBar() {

        hostingController?.view.removeFromSuperview()
        tabBarController?.tabBar.isHidden = false
    }
}

struct MediaTabBarSelectView: View {

    @ObservedObject var tabBarSelect: NCMediaTabbarSelect

    var body: some View {
        ZStack(alignment: .top) {
            Color(UIColor.systemBackground).ignoresSafeArea()
            VStack {
                Divider()
                Button("Unselect") {
                    tabBarSelect.delegate?.unselect(tabBarSelect: tabBarSelect)
                }
                Button("delete") {
                    tabBarSelect.delegate?.delete(tabBarSelect: tabBarSelect)
                }.disabled(self.tabBarSelect.selectCount == 0)
                Text("Counter" + String(self.tabBarSelect.selectCount))
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }.onAppear {

        }
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    MediaTabBarSelectView(tabBarSelect: NCMediaTabbarSelect(height: 80))
}
