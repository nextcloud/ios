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

    var tabBarController: UITabBarController?
    var hostingController: UIViewController?
    open weak var delegate: NCTabBarSelectDelegate?

    @Published var selectCount: Int = 0

    init(tabBarController: UITabBarController? = nil, height: CGFloat = 83, delegate: NCTabBarSelectDelegate? = nil) {

        guard let tabBarController else { return }
        let height = height + tabBarController.view.safeAreaInsets.bottom
        let hostingController = UIHostingController(rootView: MediaTabBarSelectView(tabBarSelect: self))

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
            hostingController.view.heightAnchor.constraint(equalToConstant: height)
        ])

        hostingController.view.backgroundColor = .clear
    }

    func removeTabBar() {

        hostingController?.view.removeFromSuperview()
        tabBarController?.tabBar.isHidden = false
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

                Text(String(tabBarSelect.selectCount) + " " + NSLocalizedString("_selected_photos_", comment: ""))
                .font(.system(size: 15))
                .fontWeight(.bold)
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
