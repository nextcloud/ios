// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

extension NCCollectionViewCommon: NCListCellDelegate, NCGridCellDelegate {
    func openContextMenu(with metadata: tableMetadata?, button: UIButton, sender: Any) {
        guard let metadata else {
            button.menu = nil
            return
        }
        let ocId = metadata.ocId
        let account = metadata.account

        // Resolve actions only when the menu opens, rather than for every cell while scrolling.
        let deferredMenu = UIDeferredMenuElement.uncached { [weak self, weak senderView = sender as? UIView] completion in
            Task { @MainActor in
                guard let self,
                      let cell = senderView as? NCCellMainProtocol,
                      let currentMetadata = cell.metadata,
                      currentMetadata.ocId == ocId,
                      currentMetadata.account == account else {
                    completion([])
                    return
                }

                let menu = NCContextMenuMain(metadata: currentMetadata, viewController: self, controller: self.controller, sender: senderView).viewMenu()
                completion(menu.children)
            }
        }
        button.menu = UIMenu(children: [deferredMenu])
    }

    func onMenuIntent(with metadata: tableMetadata?) {
        Task {
            await self.debouncerReloadData.pause()
        }
    }

    func tapShareListItem(with metadata: tableMetadata?, button: UIButton, sender: Any) {
        Task {
            guard let metadata else { return }
            NCCreate().createShare(controller: self.controller, presentViewController: self.controller, metadata: metadata, page: .sharing)
        }
    }
}
