extension NCCollectionViewCommon: NCListCellDelegate, NCGridCellDelegate {
    func openContextMenu(with metadata: tableMetadata?, button: UIButton, sender: Any) {
        Task {
            guard let metadata else { return }
            button.menu = NCContextMenuMain(metadata: metadata,
                                            viewController: self,
                                            controller: self.controller,
                                            sender: sender).viewMenu()
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
            NCCreate().createShare(controller: self.controller, metadata: metadata, page: .sharing)
        }
    }
}
