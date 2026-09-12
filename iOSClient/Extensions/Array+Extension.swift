// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Found in Internet

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

    func asyncFilter(_ isIncluded: @escaping (Element) async -> Bool) async -> [Element] {
        var result: [Element] = []
        for element in self {
            if await isIncluded(element) {
                result.append(element)
            }
        }
        return result
    }
}

extension Array where Element == URLQueryItem {
    subscript(name: String) -> URLQueryItem? {
        first(where: { $0.name == name })
    }
}
