// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

final class NCDebouncer {
    private let delay: TimeInterval
    private let maxEventCount: Int
    private var eventCount = 0
    private var timer: Timer?
    private var latestBlock: (() -> Void)?

    init(delay: TimeInterval, maxEventCount: Int = 10) {
        self.delay = delay
        self.maxEventCount = maxEventCount
    }

    func call(_ block: @escaping () -> Void, immediate: Bool = false) {
        if immediate {
            latestBlock = block
            return commit()
        }

        latestBlock = block
        eventCount += 1

        if timer == nil {
            let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
                self?.commit()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        if eventCount >= maxEventCount {
            commit()
        }
    }

    private func commit() {
        timer?.invalidate()
        timer = nil
        eventCount = 0
        latestBlock?()
        latestBlock = nil
    }
}
