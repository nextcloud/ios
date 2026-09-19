// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Found in Internet

import Foundation
import UIKit

public class ActionClosure {

    public let selector: Selector
    private let closure: (_ sendersender: Any?) -> Void

    init(_ attachObj: AnyObject, closure: @escaping (_ sender: Any?) -> Void) {
        self.closure = closure
        self.selector = #selector(target(_ :))
        objc_setAssociatedObject(attachObj, UUID().uuidString, self, .OBJC_ASSOCIATION_RETAIN)
    }

    @objc func target(_ sender: Any?) {
        closure(sender)
    }
}

public extension UIControl {
    func action(for event: UIControl.Event, _ closure: @escaping (_ object: Any?) -> Void) {
        let actionClosure = ActionClosure(self, closure: closure)
        self.addTarget(actionClosure, action: actionClosure.selector, for: event)
    }
}
