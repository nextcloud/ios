// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

extension tableMetadata {
    /// The saved `sessionError`, worded for people from its `errorCode` and the operation the item failed at.
    var sessionErrorMessage: String {
        let error = NKError(errorCode: errorCode, errorDescription: sessionError)
        let context = NCErrorContext(metadataStatus: status, fileName: fileNameView)

        return error.userMessage(for: context) ?? error.localizedGenericMessage
    }
}
