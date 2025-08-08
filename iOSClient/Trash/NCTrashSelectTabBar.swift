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

    init(controller: UITabBarController? = nil, viewController: UIViewController, delegate: NCTrashSelectTabBarDelegate? = nil) {
        guard let controller else {
            return
        }
        let rootView = NCTrashSelectTabBarView(tabBarSelect: self)
        let bottomAreaInsets: CGFloat = controller.tabBar.safeAreaInsets.bottom == 0 ? 34 : 0
        let height = controller.tabBar.frame.height + bottomAreaInsets
        hostingController = UIHostingController(rootView: rootView)
        guard let hostingController else {
            return
        }

        self.controller = controller
        self.delegate = delegate

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        hostingController.view.isHidden = true

        viewController.view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: height)
        ])
    }

    func show() {
        guard let controller,
              let hostingController else {
            return
        }

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
              let hostingController else {
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
                    Image(systemName: "arrow.counterclockwise")
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
    NCTrashSelectTabBarView(tabBarSelect: NCTrashSelectTabBar(viewController: UIViewController()))
}
