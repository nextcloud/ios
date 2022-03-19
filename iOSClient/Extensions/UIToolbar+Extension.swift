//
//  UIToolbar+Extension.swift
//  Nextcloud
//
//  Created by Henrik Storch on 18.03.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Foundation

extension UIToolbar {
    static func toolbar(onClear: (() -> Void)?, completion: @escaping () -> Void) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        var buttons: [UIBarButtonItem] = []
        let doneButton = UIBarButtonItem(title: NSLocalizedString("_done_", comment: ""), style: .done) {
            completion()
        }
        buttons.append(doneButton)

        if let onClear = onClear {
            let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
            let clearButton = UIBarButtonItem(title: NSLocalizedString("_clear_", comment: ""), style: .plain) {
                onClear()
            }
            buttons.append(contentsOf: [spaceButton, clearButton])
        }
        toolbar.setItems(buttons, animated: false)
        return toolbar
    }
}
