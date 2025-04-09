//
//  UIToolbar+Extension.swift
//  Nextcloud
//
//  Created by Henrik Storch on 18.03.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

extension UIToolbar {
    static func toolbar(onClear: (() -> Void)?, onDone: @escaping () -> Void) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        var buttons: [UIBarButtonItem] = []

        if let onClear = onClear {
            let clearButton = UIBarButtonItem(title: NSLocalizedString("_clear_", comment: ""), style: .plain) {
                onClear()
            }
            buttons.append(clearButton)
        }
        buttons.append(UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil))
        let doneButton = UIBarButtonItem(title: NSLocalizedString("_done_", comment: ""), style: .done) {
            onDone()
        }
        buttons.append(doneButton)
        toolbar.setItems(buttons, animated: false)
        return toolbar
    }

    // by default inputAccessoryView does not respect safeArea
    var wrappedSafeAreaContainer: UIView {
        let view = InputBarWrapper()
        view.addSubview(self)
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.topAnchor.constraint(equalTo: view.topAnchor),
            self.leftAnchor.constraint(equalTo: view.leftAnchor),
            self.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            self.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
        return view
    }
}

// https://stackoverflow.com/a/67985180/9506784
class InputBarWrapper: UIView {

    var desiredHeight: CGFloat = 0 {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var intrinsicContentSize: CGSize { CGSize(width: 0, height: desiredHeight) }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        autoresizingMask = .flexibleHeight
    }
}
