//
//  Array+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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

// https://stackoverflow.com/questions/33861036/unique-objects-inside-a-array-swift/45023247#45023247
extension Array {

    func unique<T: Hashable>(map: ((Element) -> (T))) -> [Element] {
        var set = Set<T>() // the unique list kept in a Set for fast retrieval
        var arrayOrdered = [Element]() // keeping the unique list of elements but ordered
        for value in self where !set.contains(map(value)) {
            set.insert(map(value))
            arrayOrdered.append(value)
        }

        return arrayOrdered
    }
}

extension Array where Element == URLQueryItem {
    subscript(name: String) -> URLQueryItem? {
        first(where: { $0.name == name })
    }
}
