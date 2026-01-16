extension NCCollectionViewCommon: NCListCellDelegate, NCGridCellDelegate, NCPhotoCellDelegate {
    func contextMenu(with metadata: tableMetadata?, button: UIButton, sender: Any) {
        Task {
            guard let metadata else { return }
            button.menu = NCContextMenu(metadata: metadata, viewController: self, sceneIdentifier: self.sceneIdentifier, sender: sender).viewMenu()
        }
    }

    func onMenuIntent(with metadata: tableMetadata?) {
        Task {
            await self.debouncerReloadData.pause()
        }
    }

    func tapShareListItem(with metadata: tableMetadata?, button: UIButton, sender: Any) {
        Task {
            guard let metadata else { return }
            NCCreate().createShare(viewController: self, metadata: metadata, page: .sharing)
        }
    }
}
