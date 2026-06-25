// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Alamofire

/// Quantizes per-task progress updates to integer percentages (0...100).
/// Each (serverUrlFileName) pair is tracked separately, so you get
/// at most one update per integer percent for each transfer.
actor ProgressQuantizer {
    private var lastPercent: [String: Int] = [:]

    /// Returns `true` only when integer percent changes (or hits 100).
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The name of the file being transferred.
    ///   - fraction: Progress fraction [0.0 ... 1.0].
    func shouldEmit(serverUrlFileName: String, fraction: Double) -> Bool {
        let percent = min(max(Int((fraction * 100).rounded(.down)), 0), 100)

        let last = lastPercent[serverUrlFileName] ?? -1
        guard percent != last || percent == 100 else {
            return false
        }

        lastPercent[serverUrlFileName] = percent
        return true
    }

    /// Clears stored state for a finished transfer.
    func clear(serverUrlFileName: String) {
        lastPercent.removeValue(forKey: serverUrlFileName)
    }
}
