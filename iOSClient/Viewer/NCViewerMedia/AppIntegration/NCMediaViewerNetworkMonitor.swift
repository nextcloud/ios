// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network

/// Reports whether the current network is unmetered: not expensive (cellular, personal hotspot)
/// and not constrained (Low Data Mode). Until the first path update arrives it reports metered,
/// so the viewer never prefetches originals on an unknown network.
final class NCMediaViewerNetworkMonitor: @unchecked Sendable {
    static let shared = NCMediaViewerNetworkMonitor()

    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var unmetered = false

    var isUnmetered: Bool {
        lock.withLock { unmetered }
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isUnmetered = path.status == .satisfied && !path.isExpensive && !path.isConstrained
            self?.lock.withLock { self?.unmetered = isUnmetered }
        }
        monitor.start(queue: DispatchQueue(label: "com.nextcloud.mediaviewer.networkmonitor", qos: .utility))
    }
}
