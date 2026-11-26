// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

@Suite("Menu presentation monitor")
@MainActor
struct NCMenuPresentationMonitorTests {
    /// Records the monitor notifications posted on a private notification center.
    private final class Recorder: NSObject {
        let center = NotificationCenter()
        private(set) var names: [Notification.Name] = []

        override init() {
            super.init()
            for name in [NCMenuPresentationMonitor.menuWillShowNotification, NCMenuPresentationMonitor.menuDidHideNotification] {
                center.addObserver(self, selector: #selector(record(_:)), name: name, object: nil)
            }
        }

        @objc private func record(_ notification: Notification) {
            names.append(notification.name)
        }
    }

    @Test("No menu is visible at start")
    func startsHidden() {
        let monitor = NCMenuPresentationMonitor(notificationCenter: NotificationCenter())

        #expect(!monitor.isMenuVisible)
    }

    @Test("Opening and closing one menu posts show and hide once")
    func singleMenu() {
        let recorder = Recorder()
        let monitor = NCMenuPresentationMonitor(notificationCenter: recorder.center)
        let owner = NSObject()

        monitor.menuWillShow(owner)
        #expect(monitor.isMenuVisible)

        monitor.menuDidHide(owner)
        #expect(!monitor.isMenuVisible)

        #expect(recorder.names == [NCMenuPresentationMonitor.menuWillShowNotification, NCMenuPresentationMonitor.menuDidHideNotification])
    }

    @Test("Hide is posted only when the last open menu closes")
    func overlappingMenus() {
        let recorder = Recorder()
        let monitor = NCMenuPresentationMonitor(notificationCenter: recorder.center)
        let first = NSObject()
        let second = NSObject()

        monitor.menuWillShow(first)
        monitor.menuWillShow(second)
        monitor.menuDidHide(first)
        #expect(monitor.isMenuVisible)

        monitor.menuDidHide(second)
        #expect(!monitor.isMenuVisible)

        #expect(recorder.names == [NCMenuPresentationMonitor.menuWillShowNotification, NCMenuPresentationMonitor.menuDidHideNotification])
    }

    @Test("Deferred actions run immediately when no menu is open")
    func actionRunsImmediately() {
        let monitor = NCMenuPresentationMonitor(notificationCenter: NotificationCenter())
        var runs = 0

        monitor.performWhenNoMenuVisible(for: NSObject()) { runs += 1 }

        #expect(runs == 1)
    }

    @Test("Deferred actions of different owners wait for the last menu to close and run in order")
    func actionsWaitForLastMenu() {
        let monitor = NCMenuPresentationMonitor(notificationCenter: NotificationCenter())
        let first = NSObject()
        let second = NSObject()
        var runs: [Int] = []

        monitor.menuWillShow(first)
        monitor.menuWillShow(second)
        monitor.performWhenNoMenuVisible(for: first) { runs.append(1) }
        monitor.performWhenNoMenuVisible(for: second) { runs.append(2) }

        monitor.menuDidHide(first)
        #expect(runs.isEmpty)

        monitor.menuDidHide(second)
        #expect(runs == [1, 2])

        monitor.menuWillShow(first)
        monitor.menuDidHide(first)
        #expect(runs == [1, 2])
    }

    @Test("Only the last deferred action of the same owner runs")
    func lastActionPerOwnerWins() {
        let monitor = NCMenuPresentationMonitor(notificationCenter: NotificationCenter())
        let menuOwner = NSObject()
        let screen = NSObject()
        var runs: [Int] = []

        monitor.menuWillShow(menuOwner)
        monitor.performWhenNoMenuVisible(for: screen) { runs.append(1) }
        monitor.performWhenNoMenuVisible(for: screen) { runs.append(2) }
        monitor.performWhenNoMenuVisible(for: screen) { runs.append(3) }
        monitor.menuDidHide(menuOwner)

        #expect(runs == [3])
    }

    @Test("Repeated or unmatched calls are ignored")
    func unbalancedCalls() {
        let recorder = Recorder()
        let monitor = NCMenuPresentationMonitor(notificationCenter: recorder.center)
        let owner = NSObject()

        monitor.menuDidHide(owner)
        monitor.menuWillShow(owner)
        monitor.menuWillShow(owner)
        monitor.menuDidHide(owner)
        monitor.menuDidHide(owner)

        #expect(!monitor.isMenuVisible)
        #expect(recorder.names == [NCMenuPresentationMonitor.menuWillShowNotification, NCMenuPresentationMonitor.menuDidHideNotification])
    }
}
