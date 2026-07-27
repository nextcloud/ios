// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension NCMedia: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session, controller: NCMainTabBarController?) {
        guard let serverUrl else { return }

        Task {
            let home = utilityFileSystem.getHomeServer(session: session)
            let mediaPath = serverUrl.replacingOccurrences(of: home, with: "")

            await database.setAccountMediaPathAsync(mediaPath, account: session.account)

            self.imageCache.removeAll()

            await self.debouncerLoadDataSource.call {
                await self.loadDataSource()
            }

            searchNewMedia()
        }
    }
}
