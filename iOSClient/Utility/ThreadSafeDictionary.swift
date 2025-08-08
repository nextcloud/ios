// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Thread-safe dictionary using a concurrent queue with synchronous barrier writes.
/// Safe for non-async code. Iteration should be done on an immutable snapshot for index stability.
public final class ThreadSafeDictionary<Key: Hashable, Value>: Collection {
    private var storage: [Key: Value]
    private let queue = DispatchQueue(label: "com.nextcloud.ThreadSafeDictionary", attributes: .concurrent)

    /// Creates a new thread-safe dictionary.
    /// - Parameter initial: Initial key/value pairs.
    public init(_ initial: [Key: Value] = [:]) {
        self.storage = initial
    }

    /// Returns the value for a key (read-only).
    public func get(_ key: Key) -> Value? {
        queue.sync { storage[key] }
    }

    /// Sets or removes a value for the given key.
    /// Uses a synchronous barrier so callers have happens-before guarantees.
    public func set(_ key: Key, _ value: Value?) {
        queue.sync(flags: .barrier) {
            if let value {
                storage[key] = value
            } else {
                storage.removeValue(forKey: key)
            }
        }
    }

    /// Atomically transforms the value for a key.
    /// Return `nil` to remove the entry.
    public func update(_ key: Key, _ transform: (Value?) -> Value?) {
        queue.sync(flags: .barrier) {
            storage[key] = transform(storage[key])
        }
    }

    /// Removes the value for a key, if it exists.
    public func removeValue(forKey key: Key) {
        _ = queue.sync(flags: .barrier) {
            storage.removeValue(forKey: key)
        }
    }

    /// Removes all entries.
    /// - Parameter keep: Whether to keep the storage capacity.
    public func removeAll(keepingCapacity keep: Bool = false) {
        queue.sync(flags: .barrier) {
            storage.removeAll(keepingCapacity: keep)
        }
    }

    /// Returns a plain dictionary snapshot for safe iteration.
    public func snapshot() -> [Key: Value] {
        queue.sync { storage }
    }

    /// Number of elements.
    public var count: Int { queue.sync { storage.count } }

    /// True if the dictionary is empty.
    public var isEmpty: Bool { queue.sync { storage.isEmpty } }

    // MARK: - Collection conformance
    // Warning: these indices are only safe if you do not mutate concurrently while iterating.
    // Prefer iterating over `snapshot()` to avoid index invalidation.

    public typealias Index = Dictionary<Key, Value>.Index
    public typealias Element = Dictionary<Key, Value>.Element

    /// The position of the first element.
    public var startIndex: Index {
        queue.sync { storage.startIndex }
    }

    /// The collection’s "past the end" position.
    public var endIndex: Index {
        queue.sync { storage.endIndex }
    }

    /// Returns the position immediately after the given index.
    public func index(after i: Index) -> Index {
        queue.sync { storage.index(after: i) }
    }

    /// Accesses the element at the given position.
    public subscript(position: Index) -> Element {
        queue.sync { storage[position] }
    }

    /// Key-based subscript with thread-safe get/set.
    public subscript(key: Key) -> Value? {
        get { queue.sync { storage[key] } }
        set {
            queue.sync(flags: .barrier) {
                storage[key] = newValue
            }
        }
    }
}
