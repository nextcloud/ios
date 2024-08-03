//
//  ThreadSafeArray.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 31/01/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  http://basememara.com/creating-thread-safe-arrays-in-swift/
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

/// A thread-safe array.
public class ThreadSafeArray<Element> {

    private var array = [Element]()
    private let queue = DispatchQueue(label: "com.nextcloud.ThreadSafeArray", attributes: .concurrent)

    public init() { }

    public convenience init(_ array: [Element]) {
        self.init()
        self.array = array
    }
}

// MARK: - Properties

public extension ThreadSafeArray {

    /// The first element of the collection.
    var first: Element? {
        var result: Element?
        queue.sync { result = self.array.first }
        return result
    }

    /// The last element of the collection.
    var last: Element? {
        var result: Element?
        queue.sync { result = self.array.last }
        return result
    }

    /// The number of elements in the array.
    var count: Int {
        var result = 0
        queue.sync { result = self.array.count }
        return result
    }

    /// A Boolean value indicating whether the collection is empty.
    var isEmpty: Bool {
        var result = false
        queue.sync { result = self.array.isEmpty }
        return result
    }

    /// A textual representation of the array and its elements.
    var description: String {
        var result = ""
        queue.sync { result = self.array.description }
        return result
    }
}

// MARK: - Immutable

public extension ThreadSafeArray {

    /// Returns the first element of the sequence that satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
    /// - Returns: The first element of the sequence that satisfies predicate, or nil if there is no element that satisfies predicate.
    func first(where predicate: (Element) -> Bool) -> Element? {
        var result: Element?
        queue.sync { result = self.array.first(where: predicate) }
        return result
    }

    /// Returns the last element of the sequence that satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
    /// - Returns: The last element of the sequence that satisfies predicate, or nil if there is no element that satisfies predicate.
    func last(where predicate: (Element) -> Bool) -> Element? {
        var result: Element?
        queue.sync { result = self.array.last(where: predicate) }
        return result
    }

    /// Returns an array containing, in order, the elements of the sequence that satisfy the given predicate.
    ///
    /// - Parameter isIncluded: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element should be included in the returned array.
    /// - Returns: An array of the elements that includeElement allowed.
    func filter(_ isIncluded: @escaping (Element) -> Bool) -> ThreadSafeArray {
        var result: ThreadSafeArray?
        queue.sync { result = ThreadSafeArray(self.array.filter(isIncluded)) }
        return result!
    }

    /// Returns the first index in which an element of the collection satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element as its argument and returns a Boolean value that indicates whether the passed element represents a match.
    /// - Returns: The index of the first element for which predicate returns true. If no elements in the collection satisfy the given predicate, returns nil.
    func index(where predicate: (Element) -> Bool) -> Int? {
        var result: Int?
        queue.sync { result = self.array.firstIndex(where: predicate) }
        return result
    }

    /// Returns the elements of the collection, sorted using the given predicate as the comparison between elements.
    ///
    /// - Parameter areInIncreasingOrder: A predicate that returns true if its first argument should be ordered before its second argument; otherwise, false.
    /// - Returns: A sorted array of the collection’s elements.
    func sorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> ThreadSafeArray {
        var result: ThreadSafeArray?
        queue.sync { result = ThreadSafeArray(self.array.sorted(by: areInIncreasingOrder)) }
        return result!
    }

    /// Returns an array containing the results of mapping the given closure over the sequence’s elements.
    ///
    /// - Parameter transform: A closure that accepts an element of this sequence as its argument and returns an optional value.
    /// - Returns: An array of the non-nil results of calling transform with each element of the sequence.
    func map<ElementOfResult>(_ transform: @escaping (Element) -> ElementOfResult) -> [ElementOfResult] {
        var result = [ElementOfResult]()
        queue.sync { result = self.array.map(transform) }
        return result
    }

    /// Returns an array containing the non-nil results of calling the given transformation with each element of this sequence.
    ///
    /// - Parameter transform: A closure that accepts an element of this sequence as its argument and returns an optional value.
    /// - Returns: An array of the non-nil results of calling transform with each element of the sequence.
    func compactMap<ElementOfResult>(_ transform: (Element) -> ElementOfResult?) -> [ElementOfResult] {
        var result = [ElementOfResult]()
        queue.sync { result = self.array.compactMap(transform) }
        return result
    }

    /// Returns the result of combining the elements of the sequence using the given closure.
    ///
    /// - Parameters:
    ///   - initialResult: The value to use as the initial accumulating value. initialResult is passed to nextPartialResult the first time the closure is executed.
    ///   - nextPartialResult: A closure that combines an accumulating value and an element of the sequence into a new accumulating value, to be used in the next call of the nextPartialResult closure or returned to the caller.
    /// - Returns: The final accumulated value. If the sequence has no elements, the result is initialResult.
    func reduce<ElementOfResult>(_ initialResult: ElementOfResult, _ nextPartialResult: @escaping (ElementOfResult, Element) -> ElementOfResult) -> ElementOfResult {
        var result: ElementOfResult?
        queue.sync { result = self.array.reduce(initialResult, nextPartialResult) }
        return result ?? initialResult
    }

    /// Returns the result of combining the elements of the sequence using the given closure.
    ///
    /// - Parameters:
    ///   - initialResult: The value to use as the initial accumulating value.
    ///   - updateAccumulatingResult: A closure that updates the accumulating value with an element of the sequence.
    /// - Returns: The final accumulated value. If the sequence has no elements, the result is initialResult.
    func reduce<ElementOfResult>(into initialResult: ElementOfResult, _ updateAccumulatingResult: @escaping (inout ElementOfResult, Element) -> Void) -> ElementOfResult {
        var result: ElementOfResult?
        queue.sync { result = self.array.reduce(into: initialResult, updateAccumulatingResult) }
        return result ?? initialResult
    }

    /// Calls the given closure on each element in the sequence in the same order as a for-in loop.
    ///
    /// - Parameter body: A closure that takes an element of the sequence as a parameter.
    func forEach(_ body: (Element) -> Void) {
        queue.sync { self.array.forEach(body) }
    }

    /// Returns a Boolean value indicating whether the sequence contains an element that satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value that indicates whether the passed element represents a match.
    /// - Returns: true if the sequence contains an element that satisfies predicate; otherwise, false.
    func contains(where predicate: (Element) -> Bool) -> Bool {
        var result = false
        queue.sync { result = self.array.contains(where: predicate) }
        return result
    }

    /// Returns a Boolean value indicating whether every element of a sequence satisfies a given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value that indicates whether the passed element satisfies a condition.
    /// - Returns: true if the sequence contains only elements that satisfy predicate; otherwise, false.
    func allSatisfy(_ predicate: (Element) -> Bool) -> Bool {
        var result = false
        queue.sync { result = self.array.allSatisfy(predicate) }
        return result
    }

    /// Returns the array
    ///
    /// - Returns: the array part.
    func getArray() -> [Element]? {
        var results: [Element]?
        queue.sync { results = self.array }
        return results
    }
}

// MARK: - Mutable

public extension ThreadSafeArray {

    /// Adds a new element at the end of the array.
    ///
    /// - Parameter element: The element to append to the array.
    func append(_ element: Element) {
        queue.async(flags: .barrier) {
            self.array.append(element)
        }
    }

    /// Adds new elements at the end of the array.
    ///
    /// - Parameter element: The elements to append to the array.
    func append(_ elements: [Element]) {
        queue.async(flags: .barrier) {
            self.array += elements
        }
    }

    /// Inserts a new element at the specified position.
    ///
    /// - Parameters:
    ///   - element: The new element to insert into the array.
    ///   - index: The position at which to insert the new element.
    func insert(_ element: Element, at index: Int) {
        queue.async(flags: .barrier) {
            self.array.insert(element, at: index)
        }
    }

    /// Removes and returns the element at the specified position.
    ///
    /// - Parameters:
    ///   - index: The position of the element to remove.
    ///   - completion: The handler with the removed element.
    func remove(at index: Int, completion: ((Element) -> Void)? = nil) {
        queue.async(flags: .barrier) {
            let element = self.array.remove(at: index)
            DispatchQueue.main.async { completion?(element) }
        }
    }

    /// Removes and returns the elements that meet the criteria.
    ///
    /// - Parameters:
    ///   - predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
    ///   - completion: The handler with the removed elements.
    func remove(where predicate: @escaping (Element) -> Bool, completion: (([Element]) -> Void)? = nil) {
        queue.async(flags: .barrier) {
            var elements = [Element]()

            while let index = self.array.firstIndex(where: predicate) {
                elements.append(self.array.remove(at: index))
            }

            DispatchQueue.main.async { completion?(elements) }
        }
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter completion: The handler with the removed elements.
    func removeAll(completion: (([Element]) -> Void)? = nil) {
        queue.async(flags: .barrier) {
            let elements = self.array
            self.array.removeAll()
            DispatchQueue.main.async { completion?(elements) }
        }
    }
}

public extension ThreadSafeArray {

    /// Accesses the element at the specified position if it exists.
    ///
    /// - Parameter index: The position of the element to access.
    /// - Returns: optional element if it exists.
    subscript(index: Int) -> Element? {
        get {
            var result: Element?

            queue.sync {
                guard self.array.startIndex..<self.array.endIndex ~= index else { return }
                result = self.array[index]
            }

            return result
        }
        set {
            guard let newValue = newValue else { return }

            queue.async(flags: .barrier) {
                self.array[index] = newValue
            }
        }
    }
}

// MARK: - Equatable

public extension ThreadSafeArray where Element: Equatable {

    /// Returns a Boolean value indicating whether the sequence contains the given element.
    ///
    /// - Parameter element: The element to find in the sequence.
    /// - Returns: true if the element was found in the sequence; otherwise, false.
    func contains(_ element: Element) -> Bool {
        var result = false
        queue.sync { result = self.array.contains(element) }
        return result
    }
}

// MARK: - Infix operators

public extension ThreadSafeArray {

    /// Adds a new element at the end of the array.
    ///
    /// - Parameters:
    ///   - left: The collection to append to.
    ///   - right: The element to append to the array.
    static func += (left: inout ThreadSafeArray, right: Element) {
        left.append(right)
    }

    /// Adds new elements at the end of the array.
    ///
    /// - Parameters:
    ///   - left: The collection to append to.
    ///   - right: The elements to append to the array.
    static func += (left: inout ThreadSafeArray, right: [Element]) {
        left.append(right)
    }
}
