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

class NCMediaTabbarSelect: ObservableObject {

    var hostingController: UIViewController!
    var mediaTabBarController: UITabBarController?
    open weak var delegate: NCTabBarSelectDelegate?

    @Published var selectCount: Int = 0

    init(tabBarController: UITabBarController? = nil, delegate: NCTabBarSelectDelegate? = nil) {

        guard let tabBarController else { return }
        let mediaTabBarSelectView = MediaTabBarSelectView(tabBarSelect: self)
        hostingController = UIHostingController(rootView: mediaTabBarSelectView)

        self.mediaTabBarController = tabBarController
        self.delegate = delegate

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

    func show(animation: Bool) {

        mediaTabBarController?.tabBar.isHidden = true
        hostingController.view.isHidden = false
    }

    func hide(animation: Bool) {

        hostingController.view.isHidden = true
        mediaTabBarController?.tabBar.isHidden = false
    }
}

struct MediaTabBarSelectView: View {

    @ObservedObject var tabBarSelect: NCMediaTabbarSelect

    var body: some View {
        VStack {
            Spacer().frame(height: 10)
            HStack {
                Button(NSLocalizedString("_cancel_", comment: "")) {
                    tabBarSelect.delegate?.cancel(tabBarSelect: tabBarSelect)
                }
                .frame(maxWidth: .infinity)

                Group {
                    if tabBarSelect.selectCount == 1 {
                        Text(String(tabBarSelect.selectCount) + " " + NSLocalizedString("_selected_photo_", comment: ""))
                    } else {
                        Text(String(tabBarSelect.selectCount) + " " + NSLocalizedString("_selected_photos_", comment: ""))
                    }
                }
                .font(.system(size: 16, weight: .bold, design: .default))
                .frame(minWidth: 220, maxWidth: .infinity)

                Button {
                    tabBarSelect.delegate?.delete(tabBarSelect: tabBarSelect)
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .disabled(tabBarSelect.selectCount == 0)
                .frame(maxWidth: .infinity)
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
