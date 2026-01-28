import NextcloudKit

final class NCSelectOpen: NCSelectDelegate {
    static let shared = NCSelectOpen()

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session) {
        if let destination = serverUrl, !items.isEmpty {
            if copy {
                for case let metadata as tableMetadata in items {
                    if metadata.status != NCGlobal.shared.metadataStatusNormal, metadata.status != NCGlobal.shared.metadataStatusWaitCopy {
                        continue
                    }

                    NCNetworking.shared.setStatusWaitCopy(metadata, destination: destination, overwrite: overwrite)
                }

            } else if move {
                for case let metadata as tableMetadata in items {
                    if metadata.status != NCGlobal.shared.metadataStatusNormal, metadata.status != NCGlobal.shared.metadataStatusWaitMove {
                        continue
                    }

                    NCNetworking.shared.setStatusWaitMove(metadata, destination: destination, overwrite: overwrite)
                }
            }
        }
    }

    func openView(items: [tableMetadata], controller: NCMainTabBarController?) {
        let utilityFileSystem = NCUtilityFileSystem()
        let session = NCSession.shared.getSession(controller: controller)
        let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController
        let topViewController = navigationController?.topViewController as? NCSelect
        var listViewController = [NCSelect]()
        var copyItems: [tableMetadata] = []
        let capabilities = NCNetworking.shared.capabilities[controller?.account ?? ""] ?? NKCapabilities.Capabilities()

        for item in items {
            if let fileNameError = FileNameValidator.checkFileName(item.fileNameView, account: controller?.account, capabilities: capabilities) {
                controller?.present(UIAlertController.warning(message: "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)
                return
            }
            copyItems.append(item)
        }

        let home = utilityFileSystem.getHomeServer(session: session)
        var serverUrl = copyItems[0].serverUrl

        // Setup view controllers such that the current view is of the same directory the items to be copied are in
        while true {
            // If not in the topmost directory, create a new view controller and set correct title.
            // If in the topmost directory, use the default view controller as the base.
            var viewController: NCSelect?
            if serverUrl != home {
                viewController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateViewController(withIdentifier: "NCSelect.storyboard") as? NCSelect
                if viewController == nil {
                    return
                }
                viewController!.titleCurrentFolder = (serverUrl as NSString).lastPathComponent
            } else {
                viewController = topViewController
            }
            guard let vc = viewController else { return }

            vc.delegate = self
            vc.typeOfCommandView = .copyMove
            vc.items = copyItems
            vc.serverUrl = serverUrl
            vc.session = session
            vc.controller = controller

            vc.navigationItem.backButtonTitle = vc.titleCurrentFolder
            listViewController.insert(vc, at: 0)

            if serverUrl != home {
                if let serverDirectoryUp = utilityFileSystem.serverDirectoryUp(serverUrl: serverUrl, home: home) {
                    serverUrl = serverDirectoryUp
                }
            } else {
                break
            }
        }

        navigationController?.setViewControllers(listViewController, animated: false)
        navigationController?.modalPresentationStyle = .formSheet

        if let navigationController = navigationController {
            controller?.present(navigationController, animated: true, completion: nil)
        }
    }
}
