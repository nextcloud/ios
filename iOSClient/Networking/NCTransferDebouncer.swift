// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

final class NCTransferDebouncer {
    private let delay: TimeInterval
    private var timer: Timer?
    private var latestBlock: (() -> Void)?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func call(_ block: @escaping () -> Void) {
        latestBlock = block
        timer?.invalidate()

        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.latestBlock?()
            self?.latestBlock = nil
        }

        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
