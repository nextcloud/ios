// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI

protocol NCMediaSelectTabBarDelegate: AnyObject {
    func delete()
}

class NCMediaSelectTabBar: ObservableObject {
    var hostingController: UIViewController?
    var controller: UITabBarController?
    open weak var delegate: NCMediaSelectTabBarDelegate?
    @Published var selectCount: Int = 0

    init(controller: UITabBarController? = nil, viewController: UIViewController, delegate: NCMediaSelectTabBarDelegate? = nil) {
        guard let controller else {
            return
        }
        let rootView = MediaTabBarSelectView(tabBarSelect: self)
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

        hostingController.view.isHidden = false
        hostingController.view.transform = .init(translationX: 0, y: hostingController.view.frame.height)
        UIView.animate(withDuration: 0.2) {
            hostingController.view.transform = .init(translationX: 0, y: 0)
        }
        controller.tabBar.isHidden = true
    }

    func hide() {
        guard let controller,
              let hostingController else {
            return
        }

        controller.tabBar.isHidden = false
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
    MediaTabBarSelectView(tabBarSelect: NCMediaSelectTabBar(controller: nil, viewController: UIViewController(), delegate: nil))
}
