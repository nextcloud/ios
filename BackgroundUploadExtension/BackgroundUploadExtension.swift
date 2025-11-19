// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Photos
import ExtensionFoundation

@main
class BackgroundUploadExtension: PHBackgroundResourceUploadExtension {
    required init() {}

    func process() -> PHBackgroundResourceUploadProcessingResult {
        // Process upload jobs.
        return .completed
    }

    func notifyTermination() {
        // Prepare for termination.
    }
}
