//
//  NCMediaTabbarSelect.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/02/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import SwiftUI

protocol NCMediaTabBarSelectDelegate: AnyObject {
    func delete()
}

class NCMediaTabbarSelect: ObservableObject {

    var hostingController: UIViewController!
    var mediaTabBarController: UITabBarController?
    open weak var delegate: NCMediaTabBarSelectDelegate?
    @Published var selectCount: Int = 0

    init(tabBarController: UITabBarController? = nil, delegate: NCMediaTabBarSelectDelegate? = nil) {
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

    func show() {
        hostingController.view.isHidden = false
        hostingController.view.transform = .init(translationX: 0, y: hostingController.view.frame.height)
        UIView.animate(withDuration: 0.2) {
            self.hostingController.view.transform = .init(translationX: 0, y: 0)
        }
        mediaTabBarController?.tabBar.isHidden = true
    }

    func hide() {

        self.mediaTabBarController?.tabBar.isHidden = false
        self.hostingController.view.isHidden = true
    }
}

struct MediaTabBarSelectView: View {
    @ObservedObject var tabBarSelect: NCMediaTabbarSelect
    @Environment(\.verticalSizeClass) var sizeClass

    var body: some View {
        VStack {
            Spacer().frame(height: sizeClass == .compact ? 5 : 10)
            HStack {
                Spacer().frame(maxWidth: .infinity)
                Group {
                    if tabBarSelect.selectCount == 0 {
                        Text(NSLocalizedString("_select_photo_", comment: ""))
                    } else if tabBarSelect.selectCount == 1 {
                        Text(String(tabBarSelect.selectCount) + " " + NSLocalizedString("_selected_photo_", comment: ""))
                    } else {
                        Text(String(tabBarSelect.selectCount) + " " + NSLocalizedString("_selected_photos_", comment: ""))
                    }
                }
                .frame(minWidth: 250, maxWidth: .infinity)

                Button {
                    tabBarSelect.delegate?.delete()
                } label: {
                    Image(systemName: "trash")
                    .imageScale(sizeClass == .compact ? .medium : .large)
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
