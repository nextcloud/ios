// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import LucidBanner
import Alamofire

class NCCreate: NSObject {
    let utility = NCUtility()
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared

    @MainActor
    func createDocument(controller: NCMainTabBarController,
                        serverUrl: String,
                        fileName: String,
                        editorId: String,
                        creatorId: String? = nil,
                        templateId: String,
                        session: NCSession.Session) async {
        let windowScene = SceneManager.shared.getWindowScene(controller: controller)
        guard let viewController = controller.currentViewController() else {
            return
        }
        let fileNamePath = utilityFileSystem.getRelativeFilePath(fileName, serverUrl: serverUrl, session: session)
        let serverUrlFileName = serverUrl + "/" + fileName

        if let creatorId, let adapter = NCDirectEditorAdapter.resolve(from: [editorId]) {
            let options = NKRequestOptions(customUserAgent: adapter.userAgent(utility))
            let results = await NextcloudKit.shared.textCreateFileAsync(fileNamePath: fileNamePath, editorId: editorId, creatorId: creatorId, templateId: templateId, account: session.account, options: options) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                                path: fileNamePath,
                                                                                                name: "textCreateFile")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            guard results.error == .success else {
                await showErrorBanner(windowScene: windowScene, text: results.error.errorDescription, errorCode: results.error.errorCode)
                return
            }

            let resultsReadFile = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrlFileName, account: session.account)
            guard resultsReadFile.error == .success, let metadata = resultsReadFile.metadata else {
                await showErrorBanner(windowScene: windowScene, text: resultsReadFile.error.errorDescription, errorCode: resultsReadFile.error.errorCode)
                return
            }

            if let vc = await NCViewer().getViewerController(metadata: metadata, delegate: viewController, viewerTransitionSource: nil) {
                viewController.navigationController?.pushViewController(vc, animated: true)
            }

        } else if editorId == "collabora" {

            let results = await NextcloudKit.shared.createRichdocumentsAsync(path: fileNamePath, templateId: templateId, account: session.account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                                path: fileNamePath,
                                                                                                name: "CreateRichdocuments")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            guard results.error == .success else {
                Task {
                    let windowScene = SceneManager.shared.getWindowScene(controller: controller)
                    await showErrorBanner(windowScene: windowScene, text: results.error.errorDescription, errorCode: results.error.errorCode)
                }
                return
            }

            let resultsReadFile = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrlFileName, account: session.account)
            guard resultsReadFile.error == .success, let metadata = resultsReadFile.metadata else {
                await showErrorBanner(windowScene: windowScene, text: resultsReadFile.error.errorDescription, errorCode: resultsReadFile.error.errorCode)
                return
            }

            if let vc = await NCViewer().getViewerController(metadata: metadata, delegate: viewController, viewerTransitionSource: nil) {
                viewController.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func getTemplate(editorId: String, templateId: String, account: String) async -> (templates: [NKEditorTemplate], selectedTemplate: NKEditorTemplate, ext: String) {
        var templates: [NKEditorTemplate] = []
        var selectedTemplate = NKEditorTemplate()
        var ext: String = ""

        if let adapter = NCDirectEditorAdapter.resolve(from: [editorId]) {
            let options = NKRequestOptions(customUserAgent: adapter.userAgent(NCUtility()))

            let results = await NextcloudKit.shared.textGetListOfTemplatesAsync(account: account, options: options) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                name: "textGetListOfTemplates")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            if results.error == .success, let resultTemplates = results.templates {
                for template in resultTemplates {
                    var temp = NKEditorTemplate()
                    temp.identifier = template.identifier
                    temp.ext = template.ext
                    temp.name = template.name
                    temp.preview = template.preview
                    templates.append(temp)
                    // default: template empty
                    if temp.preview.isEmpty {
                        selectedTemplate = temp
                        ext = template.ext
                    }
                }
            }

            if templates.isEmpty {
                var temp = NKEditorTemplate()
                temp.identifier = ""
                temp.ext = adapter.defaultExt(templateId)
                temp.name = "Empty"
                temp.preview = ""
                templates.append(temp)
                selectedTemplate = temp
                ext = temp.ext
            }
        }

        if editorId == "collabora" {
            let results = await NextcloudKit.shared.getTemplatesRichdocumentsAsync(typeTemplate: templateId, account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                path: templateId,
                                                                                                name: "getTemplatesRichdocuments")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            if results.error == .success {
                for template in results.templates! {
                    var temp = NKEditorTemplate()
                    temp.identifier = "\(template.templateId)"
                    temp.ext = template.ext
                    temp.name = template.name
                    temp.preview = template.preview
                    templates.append(temp)
                    // default: template empty
                    if temp.preview.isEmpty {
                        selectedTemplate = temp
                        ext = temp.ext
                    }
                }
            }
        }

        return (templates, selectedTemplate, ext)
    }

    func createShare(controller: NCMainTabBarController?, presentViewController: UIViewController?, metadata: tableMetadata, page: NCBrandOptions.NCInfoPagingTab) {
        guard let controller else {
            return
        }
        let capabilities = NCNetworking.shared.capabilities[metadata.account] ?? NKCapabilities.Capabilities()

        NCNetworking.shared.readFile(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account) { _, metadata, file, error in
            Task { @MainActor in
                if let metadata = metadata, let file = file, error == .success {
                    // Remove all known download limits from shares related to the given file.
                    // This avoids obsolete download limit objects to stay around.
                    // Afterwards create new download limits, should any such be returned for the known shares.
                    let shares = await NCManageDatabase.shared.getTableSharesAsync(account: metadata.account,
                                                                                   serverUrl: metadata.serverUrl,
                                                                                   fileName: metadata.fileName)
                    for share in shares {
                        await NCManageDatabase.shared.deleteDownloadLimitAsync(byAccount: metadata.account, shareToken: share.token)

                        if let receivedDownloadLimit = file.downloadLimits.first(where: { $0.token == share.token }) {
                            await NCManageDatabase.shared.createDownloadLimitAsync(account: metadata.account,
                                                                                   count: receivedDownloadLimit.count,
                                                                                   limit: receivedDownloadLimit.limit,
                                                                                   token: receivedDownloadLimit.token)
                        }
                    }

                    var pages: [NCBrandOptions.NCInfoPagingTab] = []
                    let shareNavigationController = UIStoryboard(name: "NCShare", bundle: nil).instantiateInitialViewController() as? UINavigationController
                    let shareViewController = shareNavigationController?.topViewController as? NCSharePaging

                    for value in NCBrandOptions.NCInfoPagingTab.allCases {
                        pages.append(value)
                    }
                    if capabilities.activity.isEmpty, let idx = pages.firstIndex(of: .activity) {
                        pages.remove(at: idx)
                    }
                    if !metadata.isSharable(), let idx = pages.firstIndex(of: .sharing) {
                        pages.remove(at: idx)
                    }

                    shareViewController?.pages = pages
                    shareViewController?.metadata = metadata
                    shareViewController?.controller = controller

                    if pages.contains(page) {
                        shareViewController?.page = page
                    } else if let page = pages.first {
                        shareViewController?.page = page
                    } else {
                        return
                    }

                    shareNavigationController?.modalPresentationStyle = .formSheet
                    if let shareNavigationController = shareNavigationController {
                        presentViewController?.present(shareNavigationController, animated: true, completion: nil)
                    }
                }
            }
        }
    }

    /// Creates and presents a UIActivityViewController for the given metadata list.
    /// - Parameters:
    ///   - selectedMetadata: List of tableMetadata items selected by the user.
    ///   - controller: Main tab bar controller used to present the activity view.
    ///   - sender: The UI element that triggered the action (for iPad popover anchoring).
    @MainActor
    func createActivityViewController(selectedMetadata: [tableMetadata], controller: NCMainTabBarController?, presentViewController: UIViewController?, sender: Any?) async {
        guard let controller, let presentViewController else {
            return
        }

        let metadatas = selectedMetadata.filter { !$0.directory }
        var exportURLs: [URL] = []
        var downloadMetadata: [(tableMetadata, URL)] = []
        let windowScene = SceneManager.shared.getWindowScene(controller: controller)
        var downloadRequest: DownloadRequest?

        for metadata in metadatas {
            let localPath = utilityFileSystem.getDirectoryProviderStorageOcId(
                metadata.ocId,
                fileName: metadata.fileNameView,
                userId: metadata.userId,
                urlBase: metadata.urlBase
            )

            if utilityFileSystem.fileProviderStorageExists(metadata),
               let url = exportFileForSharing(from: URL(fileURLWithPath: localPath)) {
                    exportURLs.append(url)
            } else {
                downloadMetadata.append((metadata, URL(fileURLWithPath: localPath)))
            }
        }

        if !downloadMetadata.isEmpty {
            let bannerResults = showHudBanner(windowScene: windowScene,
                                              title: "_download_in_progress_",
                                              stage: .button) {
                if let downloadRequest {
                    downloadRequest.cancel()
                }
            }

            for (originalMetadata, localFileURL) in downloadMetadata {
                guard let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(
                    ocId: originalMetadata.ocId,
                    session: NCNetworking.shared.sessionDownload,
                    selector: "",
                    sceneIdentifier: controller.sceneIdentifier
                ) else {
                    if let banner = bannerResults.banner {
                        banner.dismiss()
                    }
                    return
                }

                let results = await NCNetworking.shared.downloadFile(
                    metadata: metadata
                ) { request in
                    downloadRequest = request
                } progressHandler: { progress in
                    Task { @MainActor in
                        bannerResults.banner?.update(
                            payload: LucidBannerPayload.Update(progress: progress.fractionCompleted),
                            for: bannerResults.token)
                    }
                }

                if results.nkError == .success {
                    if let url = exportFileForSharing(from: localFileURL) {
                        exportURLs.append(url)
                    }
                }
            }

            if let banner = bannerResults.banner {
                banner.dismiss()
            }
        }

        guard !exportURLs.isEmpty else { return }

        let activityViewController = UIActivityViewController(activityItems: exportURLs, applicationActivities: nil)

        // iPad popover configuration
        if let popover = activityViewController.popoverPresentationController {
            if let barButtonItem = sender as? UIBarButtonItem {
                // Anchor the popover to the bar button item.
                popover.barButtonItem = barButtonItem

            } else if let sourceView = sender as? UIView {
                // Anchor the popover to the sender view.
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds

            } else {
                // Fallback: anchor the popover to the center of the presenting view.
                popover.sourceView = presentViewController.view
                popover.sourceRect = CGRect(
                    x: presentViewController.view.bounds.midX,
                    y: presentViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
        }

        presentViewController.present(activityViewController, animated: true)
    }

    // MARK: - Private helper

    /// Copies a file from internal/provider storage to a shareable temporary location.
    /// This makes the URL safe to pass to UIActivityViewController, "Copy", etc.
    private func exportFileForSharing(from sourceURL: URL) -> URL? {
        let fileManager = FileManager.default
        let exportBaseURL = fileManager.temporaryDirectory.appendingPathComponent("ShareExports", isDirectory: true)

        do {
            if !fileManager.fileExists(atPath: exportBaseURL.path) {
                try fileManager.createDirectory(
                    at: exportBaseURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            // Destination file path (we can just reuse lastPathComponent)
            let destinationURL = exportBaseURL.appendingPathComponent(sourceURL.lastPathComponent, isDirectory: false)

            // Remove previous copy if it exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.copyItem(at: sourceURL, to: destinationURL)

            return destinationURL
        } catch {
            return nil
        }
    }
}
