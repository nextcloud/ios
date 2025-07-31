// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI

protocol NCMediaSelectTabBarDelegate: AnyObject {
    func delete()
}

class NCMediaSelectTabBar: ObservableObject {
    var hostingController: UIViewController!
    var controller: UITabBarController?
    open weak var delegate: NCMediaSelectTabBarDelegate?
    @Published var selectCount: Int = 0

    init(controller: UITabBarController? = nil, delegate: NCMediaSelectTabBarDelegate? = nil) {
        guard let controller else { return }
        let mediaTabBarSelectView = MediaTabBarSelectView(tabBarSelect: self)
        hostingController = UIHostingController(rootView: mediaTabBarSelectView)

        self.controller = controller
        self.delegate = delegate

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
        hostingController.view.isHidden = false
        hostingController.view.transform = .init(translationX: 0, y: hostingController.view.frame.height)
        UIView.animate(withDuration: 0.2) {
            self.hostingController.view.transform = .init(translationX: 0, y: 0)
        }
        controller?.tabBar.isHidden = true
    }

    func hide() {
        controller?.tabBar.isHidden = false
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
