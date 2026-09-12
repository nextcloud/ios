// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Henrik Storch
// SPDX-License-Identifier: GPL-3.0-or-later

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
        let doneButton = UIBarButtonItem(title: NSLocalizedString("_done_", comment: ""), style: .plain) {
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
