//
//  NCTrashSelectTabBar.swift
//  Nextcloud
//
//  Created by Milen on 05.02.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

import Foundation
import UIKit
import SwiftUI

protocol NCTrashSelectTabBarDelegate: AnyObject {
    func selectAll()
    func recover()
    func delete()
}

class NCTrashSelectTabBar: ObservableObject {
    var controller: UITabBarController?
    var hostingController: UIViewController?
    open weak var delegate: NCTrashSelectTabBarDelegate?

    @Published var isSelectedEmpty = true

    init(controller: UITabBarController? = nil, delegate: NCTrashSelectTabBarDelegate? = nil) {
        let rootView = NCTrashSelectTabBarView(tabBarSelect: self)
        hostingController = UIHostingController(rootView: rootView)

        self.controller = controller
        self.delegate = delegate

        guard let controller, let hostingController else { return }

        setFrame()

        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.view.backgroundColor = .clear
        hostingController.view.isHidden = true

        controller.view.addSubview(hostingController.view)
    }

    func setFrame() {
        guard let controller,
              let hostingController
        else {
            return
        }
        let bottomAreaInsets: CGFloat = controller.tabBar.safeAreaInsets.bottom == 0 ? 34 : 0

        hostingController.view.frame = CGRect(x: controller.tabBar.frame.origin.x,
                                              y: controller.tabBar.frame.origin.y - bottomAreaInsets,
                                              width: controller.tabBar.frame.width,
                                              height: controller.tabBar.frame.height + bottomAreaInsets)
    }

    func show() {
        guard let controller,
              let hostingController else { return }

        controller.tabBar.isHidden = true

        if hostingController.view.isHidden {
            hostingController.view.isHidden = false

            hostingController.view.transform = .init(translationX: 0, y: hostingController.view.frame.height)

            UIView.animate(withDuration: 0.2) {
                hostingController.view.transform = .init(translationX: 0, y: 0)
            }
        }
    }

    func hide() {
        guard let controller,
              let hostingController
        else {
            return
        }

        hostingController.view.isHidden = true
        controller.tabBar.isHidden = false
    }

    func update(selectOcId: [String]) {
        isSelectedEmpty = selectOcId.isEmpty
    }

    func isHidden() -> Bool {
        guard let hostingController else { return false }
        return hostingController.view.isHidden
    }
}

struct NCTrashSelectTabBarView: View {
    @ObservedObject var tabBarSelect: NCTrashSelectTabBar
    @Environment(\.verticalSizeClass) var sizeClass

    var body: some View {
        VStack {
            Spacer().frame(height: sizeClass == .compact ? 5 : 10)
            HStack {
                Button {
                    tabBarSelect.delegate?.recover()
                } label: {
                    Image(systemName: "arrow.circlepath")
                        .font(Font.system(.body).weight(.light))
                        .imageScale(sizeClass == .compact ? .medium : .large)
                }
                .tint(Color(NCBrandColor.shared.iconImageColor))
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty)

                Button {
                    tabBarSelect.delegate?.delete()
                } label: {
                    Image(systemName: "trash")
                        .font(Font.system(.body).weight(.light))
                        .imageScale(sizeClass == .compact ? .medium : .large)
                }
                .tint(.red)
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty)

                Button {
                    tabBarSelect.delegate?.selectAll()
                } label: {
                    Image(systemName: "checkmark")
                        .font(Font.system(.body).weight(.light))
                        .imageScale(sizeClass == .compact ? .medium : .large)
                }
                .tint(Color(NCBrandColor.shared.iconImageColor))
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial)
        .overlay(Rectangle().frame(width: nil, height: 0.5, alignment: .top).foregroundColor(Color(UIColor.separator)), alignment: .top)
    }
}

#Preview {
    NCTrashSelectTabBarView(tabBarSelect: NCTrashSelectTabBar())
}
