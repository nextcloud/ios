//
//  UIControl+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/08/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Found in Internet
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
