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

protocol NCMediaSelectTabBarDelegate: AnyObject {
    func delete()
}

class NCMediaSelectTabBar: ObservableObject {
    var hostingController: UIViewController!
    var mediaTabBarController: UITabBarController?
    open weak var delegate: NCMediaSelectTabBarDelegate?
    @Published var selectCount: Int = 0

    init(tabBarController: UITabBarController? = nil, delegate: NCMediaSelectTabBarDelegate? = nil) {
        guard let tabBarController else { return }
        let mediaTabBarSelectView = MediaTabBarSelectView(tabBarSelect: self)
        hostingController = UIHostingController(rootView: mediaTabBarSelectView)

        self.mediaTabBarController = tabBarController
        self.delegate = delegate

        tabBarController.view.addSubview(hostingController.view)

        hostingController.view.frame = tabBarController.tabBar.frame
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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
        mediaTabBarController?.tabBar.isHidden = false
        hostingController.view.isHidden = true
    }
}

struct MediaTabBarSelectView: View {
    @ObservedObject var tabBarSelect: NCMediaSelectTabBar
    @Environment(\.verticalSizeClass) var sizeClass

    var body: some View {
        VStack {
            Spacer().frame(height: sizeClass == .compact ? 5 : 10)
            HStack {
                Spacer().frame(maxWidth: .infinity)
                Group {
                    if tabBarSelect.selectCount == 0 {
                        Text(NSLocalizedString("_select_photos_", comment: ""))
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
                    .font(Font.system(.body).weight(.light))
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
    MediaTabBarSelectView(tabBarSelect: NCMediaSelectTabBar())
}
