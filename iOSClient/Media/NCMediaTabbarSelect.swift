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

class NCMediaUIHostingController: UIHostingController<MediaTabBarSelectView> {

    var mediaTabBarController: UITabBarController?
    var heightAnchor: NSLayoutConstraint?
    var bottomAnchor: NSLayoutConstraint?

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in

            if let tabBarController = self.mediaTabBarController,
               let heightAnchor = self.heightAnchor,
               let bottomAnchor = self.bottomAnchor {

                let height = tabBarController.tabBar.frame.height
                let safeAreaInsetsBottom = tabBarController.view.safeAreaInsets.bottom

                self.bottomAnchor?.isActive = false
                self.view.removeConstraint(bottomAnchor)
                self.bottomAnchor = self.view.bottomAnchor.constraint(equalTo: tabBarController.view.bottomAnchor, constant: safeAreaInsetsBottom)
                self.bottomAnchor?.isActive = true

                self.heightAnchor?.isActive = false
                self.view.removeConstraint(heightAnchor)
                self.heightAnchor = self.view.heightAnchor.constraint(equalToConstant: height + safeAreaInsetsBottom)
                self.heightAnchor?.isActive = true
            }
        }
    }
}

class NCMediaTabbarSelect: ObservableObject {

    var mediaTabBarController: UITabBarController?
    var mediaUIHostingController: NCMediaUIHostingController!
    open weak var delegate: NCTabBarSelectDelegate?

    @Published var selectCount: Int = 0

    init(tabBarController: UITabBarController? = nil, delegate: NCTabBarSelectDelegate? = nil) {

        guard let tabBarController else { return }
        let height = tabBarController.tabBar.frame.height + tabBarController.view.safeAreaInsets.bottom
        let mediaTabBarSelectView = MediaTabBarSelectView(tabBarSelect: self)
        mediaUIHostingController = NCMediaUIHostingController(rootView: mediaTabBarSelectView)

        self.mediaTabBarController = tabBarController
        self.delegate = delegate

        tabBarController.addChild(mediaUIHostingController)
        tabBarController.view.addSubview(mediaUIHostingController.view)

        mediaUIHostingController.mediaTabBarController = mediaTabBarController
        mediaUIHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        mediaUIHostingController.view.rightAnchor.constraint(equalTo: tabBarController.view.rightAnchor).isActive = true
        mediaUIHostingController.view.leftAnchor.constraint(equalTo: tabBarController.view.leftAnchor).isActive = true

        mediaUIHostingController.bottomAnchor = mediaUIHostingController.view.bottomAnchor.constraint(equalTo: tabBarController.view.bottomAnchor, constant: tabBarController.view.safeAreaInsets.bottom)
        mediaUIHostingController.bottomAnchor?.isActive = true

        mediaUIHostingController.heightAnchor = mediaUIHostingController.view.heightAnchor.constraint(equalToConstant: height)
        mediaUIHostingController.heightAnchor?.isActive = true

        mediaUIHostingController.view.backgroundColor = .clear
        mediaUIHostingController.view.isHidden = true
    }

    func show(animation: Bool) {

        mediaTabBarController?.tabBar.isHidden = true
        mediaUIHostingController.view.isHidden = false
    }

    func hide(animation: Bool) {

        mediaUIHostingController.view.isHidden = true
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
