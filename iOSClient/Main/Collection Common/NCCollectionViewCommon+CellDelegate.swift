extension NCCollectionViewCommon: NCListCellDelegate, NCGridCellDelegate {
    func openContextMenu(with metadata: tableMetadata?, button: UIButton, sender: Any) {
        Task {
            guard let metadata else { return }
            button.menu = NCContextMenuMain(metadata: metadata, viewController: self, sceneIdentifier: self.sceneIdentifier, sender: sender).viewMenu()
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
