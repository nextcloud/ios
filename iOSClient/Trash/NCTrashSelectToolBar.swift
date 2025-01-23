//
//  NCTrashSelectTabBar.swift
//  Nextcloud
//
//  Created by Milen on 05.02.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//  Copyright © 2024 STRATO GmbH
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
import SwiftUI

protocol NCTrashSelectTabBarDelegate: AnyObject {
    func selectAll()
    func recover()
    func delete()
}

class NCTrashSelectToolBar: ObservableObject {
    var hostingController: UIViewController?
    open weak var delegate: NCTrashSelectTabBarDelegate?

    @Published var isSelectedEmpty = true

	init(containerView: UIView, placeholderFrame: CGRect, delegate: NCTrashSelectTabBarDelegate? = nil) {
        let rootView = NCTrashSelectTabBarView(tabBarSelect: self)
        hostingController = UIHostingController(rootView: rootView)

        self.delegate = delegate

        guard let hostingController else { return }

		containerView.addSubview(hostingController.view)

        hostingController.view.frame = placeholderFrame
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.view.backgroundColor = .clear
        hostingController.view.isHidden = true
    }

    func show() {
        guard let hostingController else { return }

        if hostingController.view.isHidden {
            hostingController.view.isHidden = false

            hostingController.view.transform = .init(translationX: 0, y: hostingController.view.frame.height)

            UIView.animate(withDuration: 0.2) {
                hostingController.view.transform = .init(translationX: 0, y: 0)
            }
        }
    }

    func hide() {
        hostingController?.view.isHidden = true
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
    @ObservedObject var tabBarSelect: NCTrashSelectToolBar
    @Environment(\.verticalSizeClass) var sizeClass

	var body: some View {
		GeometryReader { geometry in
			let isWideScreen = geometry.size.width > AppScreenConstants.compactMaxSize
			let eightyPercentOfWidth = geometry.size.width * 0.85
			VStack {
				Spacer().frame(height: 10)

				HStack(alignment: .top) {
					TabButton(
						action: { tabBarSelect.delegate?.recover() },
                        image: .SelectTabBar.restoreFromTrash,
						label: "_restore_" ,
						isDisabled: tabBarSelect.isSelectedEmpty,
						isOneRowStyle: isWideScreen
					)
					TabButton(
						action: { tabBarSelect.delegate?.delete() },
						image: .SelectTabBar.delete,
						label: "_delete_",
						isDisabled: tabBarSelect.isSelectedEmpty,
						isOneRowStyle: isWideScreen
					)
				}
				.frame(maxWidth: isWideScreen ? eightyPercentOfWidth : .infinity)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
			.background(Color(.Tabbar.background))
		}
	}	
}
