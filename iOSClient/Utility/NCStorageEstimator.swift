// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos

// MARK: - Models

/// Average size assumptions for a Live Photo (photo + paired video)
public struct LivePhotoAverage {
    /// Average still image size (HEIC/JPEG) in megabytes
    public var avgPhotoMB: Double
    /// Average paired video size (MOV) in megabytes
    public var avgVideoMB: Double
    /// Per-item overhead in megabytes (filenames, small sidecar, FS overhead)
    public var overheadMB: Double

    public init(avgPhotoMB: Double = 4.5, avgVideoMB: Double = 2.5, overheadMB: Double = 0.2) {
        self.avgPhotoMB = avgPhotoMB
        self.avgVideoMB = avgVideoMB
        self.overheadMB = overheadMB
    }
}

/// Result of capacity computation for staging directory
public struct StagingCapacityResult {
    /// How many Live Photos can fit under the chosen constraints
    public let maxLivePhotos: Int
    /// Bytes required per Live Photo (photo + video + overhead)
    public let bytesPerItem: Int64
    /// Total bytes reserved for staging (free - hardReserve) times safetyFactor
    public let stagingBudgetBytes: Int64
}

// MARK: - Disk/Capacity helpers

/// Returns free disk space (bytes) for the current app container filesystem.
public func diskFreeBytes() -> Int64 {
    let url = URL(fileURLWithPath: NSHomeDirectory() as String)
    if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
       let free = values.volumeAvailableCapacityForImportantUsage {
        return Int64(truncatingIfNeeded: free)
    }
    // Fallback (less precise)
    let attrs = try? FileManager.default.attributesOfFileSystem(forPath: url.path)
    let free = (attrs?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    return free
}

/// Compute how many Live Photos can fit into staging, given averages and constraints.
/// - Parameters:
///   - freeBytes: current free bytes on the device (e.g., from `diskFreeBytes()`).
///   - hardReserveBytes: bytes you want to keep untouched (safety reserve you never use).
///   - safetyFactor: extra safety (0.0...1.0). 0.8 means "use at most 80% of (free - reserve)".
///   - avg: average sizes for Live Photo components.
/// - Returns: capacity result (max items, per-item bytes, budget).
public func computeStagingCapacity(freeBytes: Int64,
                                   hardReserveBytes: Int64,
                                   safetyFactor: Double = 0.8,
                                   avg: LivePhotoAverage = .init()) -> StagingCapacityResult {
    // Clamp safety factor
    let sf = max(0.1, min(safetyFactor, 1.0))

    // Per-item bytes (photo + video + overhead)
    let bytesPerItem = Int64((avg.avgPhotoMB + avg.avgVideoMB + avg.overheadMB) * 1024 * 1024)

    // Budget available for staging
    let usable = max(0, freeBytes - hardReserveBytes)
    let budget = Int64(Double(usable) * sf)

    let maxItems = bytesPerItem > 0 ? Int(budget / bytesPerItem) : 0
    return StagingCapacityResult(maxLivePhotos: maxItems, bytesPerItem: bytesPerItem, stagingBudgetBytes: budget)
}

/// Compute how many bytes are needed to stage a target number of Live Photos.
public func bytesRequiredForLivePhotos(count: Int, avg: LivePhotoAverage = .init()) -> Int64 {
    let perItem = Int64((avg.avgPhotoMB + avg.avgVideoMB + avg.overheadMB) * 1024 * 1024)
    return perItem * Int64(max(0, count))
}

// MARK: - Example usage

/*
public func exampleCapacityComputation() {
    // 1) Read current free space
    let free = diskFreeBytes()

    // 2) Policy: keep at least 10 GB untouched (hard reserve)
    let hardReserveBytes: Int64 = 10 * 1024 * 1024 * 1024

    // 3) Averages for Live Photo (tune these with your telemetry)
    let avg = LivePhotoAverage(avgPhotoMB: 3.5, avgVideoMB: 2.5, overheadMB: 0.2)

    // 4) Safety factor: use at most 80% of usable space (free - reserve)
    let cap = computeStagingCapacity(freeBytes: free, hardReserveBytes: hardReserveBytes, safetyFactor: 0.8, avg: avg)

    // 5) Print results (replace with your logger)
    let mbPerItem = Double(cap.bytesPerItem) / (1024*1024)
    let budgetMB  = Double(cap.stagingBudgetBytes) / (1024*1024)
    print("Staging budget ≈ \(Int(budgetMB)) MB, item ≈ \(String(format: "%.1f", mbPerItem)) MB → max \(cap.maxLivePhotos) Live Photos")

    // 6) If you want exactly N items, compute required bytes
    let want = 200
    let needBytes = bytesRequiredForLivePhotos(count: want, avg: avg)
    let needMB = Double(needBytes) / (1024*1024)
    print("To stage \(want) Live Photos you need ≈ \(Int(needMB)) MB")
}
*/
