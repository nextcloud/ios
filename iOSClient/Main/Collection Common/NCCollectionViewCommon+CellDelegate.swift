extension NCCollectionViewCommon: NCListCellDelegate, NCGridCellDelegate, NCPhotoCellDelegate {
    func contextMenu(with ocId: String, button: UIButton, sender: Any) {
        Task {
            guard let metadata = await self.database.getMetadataFromOcIdAsync(ocId) else { return }
            button.menu = NCContextMenu(metadata: metadata, viewController: self, sceneIdentifier: self.sceneIdentifier, sender: sender).viewMenu()
        }
    }

    func onMenuIntent(with ocId: String) {
        print("TAP")
    }

    func tapShareListItem(with ocId: String, button: UIButton, sender: Any) {
        Task {
            guard let metadata = await self.database.getMetadataFromOcIdAsync(ocId) else { return }
            NCCreate().createShare(viewController: self, metadata: metadata, page: .sharing)
        }
    }
}
