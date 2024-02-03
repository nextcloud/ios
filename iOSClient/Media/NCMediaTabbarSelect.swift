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
    func cancel(tabBarSelect: NCMediaTabbarSelect)
    func delete(tabBarSelect: NCMediaTabbarSelect)
}

class NCMediaUIHostingController<Content>: UIHostingController<Content> where Content: View {

    var heightAnchor: NSLayoutConstraint?
    var bottomAnchor: NSLayoutConstraint?

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in
            if let height = self.tabBarController?.tabBar.frame.height,
               let safeAreaInsetsBottom = self.tabBarController?.view.safeAreaInsets.bottom {
                // self.heightAnchor?.constant = height + safeAreaInsetsBottom
                // self.bottomAnchor?.constant = safeAreaInsetsBottom
            }
        }
    }
}

class NCMediaTabbarSelect: ObservableObject {

    var mediaTabBarController: UITabBarController?
    var hostingController: UIViewController?
    open weak var delegate: NCTabBarSelectDelegate?

    @Published var selectCount: Int = 0

    init(tabBarController: UITabBarController? = nil, delegate: NCTabBarSelectDelegate? = nil) {

        guard let tabBarController else { return }
        let height = tabBarController.tabBar.frame.height + tabBarController.view.safeAreaInsets.bottom
        let mediaTabBarSelectView = MediaTabBarSelectView(tabBarSelect: self)
        let hostingController = NCMediaUIHostingController(rootView: mediaTabBarSelectView)

        self.mediaTabBarController = tabBarController
        self.hostingController = hostingController
        self.delegate = delegate

        tabBarController.tabBar.isHidden = true
        tabBarController.addChild(hostingController)
        tabBarController.view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.rightAnchor.constraint(equalTo: tabBarController.view.rightAnchor).isActive = true
        hostingController.view.leftAnchor.constraint(equalTo: tabBarController.view.leftAnchor).isActive = true

        hostingController.bottomAnchor = hostingController.view.bottomAnchor.constraint(equalTo: tabBarController.view.bottomAnchor, constant: tabBarController.view.safeAreaInsets.bottom)
        hostingController.bottomAnchor?.isActive = true

        hostingController.heightAnchor = hostingController.view.heightAnchor.constraint(equalToConstant: height)
        hostingController.heightAnchor?.isActive = true

        hostingController.view.backgroundColor = .clear
    }

    func removeTabBar() {

        hostingController?.view.removeFromSuperview()
        mediaTabBarController?.tabBar.isHidden = false
    }
}

struct MediaTabBarSelectView: View {

    @ObservedObject var tabBarSelect: NCMediaTabbarSelect

    var body: some View {
        VStack {
            Spacer().frame(height: 10)
            HStack {
                Spacer()
                .frame(width: 15.0)

                Button(NSLocalizedString("_cancel_", comment: "")) {
                    tabBarSelect.delegate?.cancel(tabBarSelect: tabBarSelect)
                }

                Spacer()

                if tabBarSelect.selectCount == 1 {
                    Text(String(tabBarSelect.selectCount) + " " + NSLocalizedString("_selected_photo_", comment: ""))
                    .font(.system(size: 15))
                    .fontWeight(.bold)
                } else {
                    Text(String(tabBarSelect.selectCount) + " " + NSLocalizedString("_selected_photos_", comment: ""))
                    .font(.system(size: 15))
                    .fontWeight(.bold)
                }

                Spacer()

                Button {
                    tabBarSelect.delegate?.delete(tabBarSelect: tabBarSelect)
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .disabled(tabBarSelect.selectCount == 0)

                Spacer()
                .frame(width: 15.0)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial)
        .overlay(Rectangle().frame(width: nil, height: 0.5, alignment: .top).foregroundColor(Color(UIColor.separator)), alignment: .top)
    }
}

#Preview {
    MediaTabBarSelectView(tabBarSelect: NCMediaTabbarSelect())
}
