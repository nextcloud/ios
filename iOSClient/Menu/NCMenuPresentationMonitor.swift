// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Keeps track of the menus that are currently open anywhere in the app.
///
/// UIKit closes an open menu when the view that owns it is destroyed, for example
/// when `reloadData()` recreates the cell that hosts a "…" button. Code that
/// refreshes the UI in the background can observe this monitor and hold back
/// those updates until the user has closed the menu.
///
/// Menu owners report their state with `menuWillShow(_:)` and `menuDidHide(_:)`.
/// `NCMenuButton` does this automatically; collection views report their
/// long-press context menus from their delegate.
///
/// Observers are told about the transitions between "no menu open" and
/// "at least one menu open" through `menuWillShowNotification` and
/// `menuDidHideNotification`, both posted on the main thread.
/// Screens without their own reload debouncer can wrap a reload in
/// `performWhenNoMenuVisible(_:)` instead.
@MainActor
final class NCMenuPresentationMonitor {
    static let shared = NCMenuPresentationMonitor()

    /// Posted when the first menu opens while no other menu is open.
    static let menuWillShowNotification = Notification.Name("NCMenuPresentationMonitorMenuWillShow")

    /// Posted when the last open menu has closed.
    static let menuDidHideNotification = Notification.Name("NCMenuPresentationMonitorMenuDidHide")

    private let notificationCenter: NotificationCenter
    private var openMenuOwners = Set<ObjectIdentifier>()
    private var pendingActions: [@MainActor () -> Void] = []

    /// `true` while at least one menu is open.
    var isMenuVisible: Bool {
        !openMenuOwners.isEmpty
    }

    /// - Parameter notificationCenter: Where the notifications are posted. Tests pass their own instance.
    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    /// Records that the menu owned by `owner` is about to be shown.
    ///
    /// Calling it again for an owner whose menu is already open has no effect.
    func menuWillShow(_ owner: AnyObject) {
        let wasVisible = isMenuVisible
        openMenuOwners.insert(ObjectIdentifier(owner))

        if !wasVisible {
            notificationCenter.post(name: Self.menuWillShowNotification, object: self)
        }
    }

    /// Records that the menu owned by `owner` has been closed.
    ///
    /// Calling it for an owner whose menu is not open has no effect.
    func menuDidHide(_ owner: AnyObject) {
        guard openMenuOwners.remove(ObjectIdentifier(owner)) != nil,
              !isMenuVisible else {
            return
        }

        let actions = pendingActions
        pendingActions.removeAll()
        for action in actions {
            action()
        }

        notificationCenter.post(name: Self.menuDidHideNotification, object: self)
    }

    /// Runs `action` now if no menu is open, otherwise when the last open menu has closed.
    ///
    /// Use it for UI updates that would destroy the view hosting an open menu, for example
    /// assigning a new data source and calling `reloadData()`. Keep the data change and the
    /// reload in the same action, so the view never shows data it has not been reloaded with.
    /// Deferred actions run in the order they were added.
    func performWhenNoMenuVisible(_ action: @escaping @MainActor () -> Void) {
        if isMenuVisible {
            pendingActions.append(action)
        } else {
            action()
        }
    }
}
