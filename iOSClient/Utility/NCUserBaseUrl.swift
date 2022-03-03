//
//  NCUtility.swift
//  Nextcloud
//
//  Created by Henrik Storch on 22.11.21.
//  Copyright © 2021 Henrik Storch. All rights reserved.
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

@objc public protocol NCUserBaseUrl {
    var user: String { get }
    var urlBase: String { get }
    var account: String { get }
}

public extension NCUserBaseUrl {
    var userBaseUrl: String {
        user + "-" + (URL(string: urlBase)?.host ?? "")
    }
}
