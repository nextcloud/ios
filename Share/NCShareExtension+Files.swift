// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-FileCopyrightText: 2021 Henrik Storch
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import UniformTypeIdentifiers
import NextcloudKit

extension NCShareExtension {
    func reloadDatasource(withLoadFolder: Bool) async {
        let session = self.extensionData.getSession()
        let layoutForView = await NCManageDatabase.shared.getLayoutForViewAsync(account: session.account, key: keyLayout, serverUrl: serverUrl)
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true", session.account, serverUrl)
        let metadatas = await self.database.getMetadatasAsync(predicate: predicate,
                                                              layoutForView: layoutForView,
                                                              account: session.account)
        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas, layoutForView: layoutForView, account: session.account)

        if withLoadFolder {
            await self.loadFolder()
        }

        self.collectionView.reloadData()
    }

    @objc func didCreateFolder(_ notification: NSNotification) {
        Task {
            guard let userInfo = notification.userInfo as NSDictionary?,
                  let ocId = userInfo["ocId"] as? String,
                  let metadata = await self.database.getMetadataFromOcIdAsync(ocId)
            else { return }

            self.serverUrl += "/" + metadata.fileName
            await self.reloadDatasource(withLoadFolder: true)
            self.setNavigationBar(navigationTitle: metadata.fileNameView)
        }
    }

    func loadFolder() async {
        let session = self.extensionData.getSession()
        let resultsReadFolder = await NCNetworking.shared.readFolderAsync(serverUrl: serverUrl, account: session.account) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        }

        if resultsReadFolder.error == .success {
            self.metadataFolder = resultsReadFolder.metadataFolder
            await self.reloadDatasource(withLoadFolder: false)
        } else {
            self.showAlert(description: resultsReadFolder.error.errorDescription)

        }
    }
}

class NCFilesExtensionHandler {
    var itemsProvider: [NSItemProvider] = []
    lazy var fileNames: [String] = []
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss-"
        return formatter
    }()

    @discardableResult
    init(items: [NSExtensionItem], completion: @escaping ([String]) -> Void) {
        NCUtilityFileSystem().emptyTemporaryDirectory()
        var counter = 0

        self.itemsProvider = items.compactMap({ $0.attachments }).flatMap { $0.filter({
            $0.hasItemConformingToTypeIdentifier(UTType.item.identifier as String) || $0.hasItemConformingToTypeIdentifier("public.url")
        }) }

        for (ix, provider) in itemsProvider.enumerated() {
            provider.loadItem(forTypeIdentifier: provider.typeIdentifier) { [self] item, error in
                defer {
                    counter += 1
                    if counter == itemsProvider.count { completion(self.fileNames) }
                }
                guard error == nil else { return }
                var originalName = (dateFormatter.string(from: Date())) + String(ix)

                if let url = item as? URL, url.isFileURL, !url.lastPathComponent.isEmpty {
                    originalName = url.lastPathComponent

                    if fileNames.contains(originalName) {
                        let incrementalNumber = NCKeychain().incrementalNumber
                        originalName = "\(url.deletingPathExtension().lastPathComponent) \(incrementalNumber).\(url.pathExtension)"
                    }
                }

                var fileName: String?
                switch item {
                case let image as UIImage:
                    fileName = getItem(image: image, fileName: originalName)
                case let url as URL:
                    fileName = getItem(url: url, fileName: originalName)
                case let data as Data:
                    fileName = getItem(data: data, fileName: originalName, provider: provider)
                case let text as String:
                    fileName = getItem(string: text, fileName: originalName)
                default: return
                }

                if let fileName, !fileNames.contains(fileName) {
                    fileNames.append(fileName)
                }
            }
        }
    }

    // Image
    func getItem(image: UIImage, fileName: String) -> String? {
        var fileUrl = URL(fileURLWithPath: NSTemporaryDirectory() + fileName)
        if fileUrl.pathExtension.isEmpty { fileUrl.appendPathExtension("png") }
        guard let pngImageData = image.pngData(), (try? pngImageData.write(to: fileUrl, options: [.atomic])) != nil
        else { return nil }
        return fileUrl.lastPathComponent
    }

    // URL
    // Does not work for directories
    func getItem(url: URL, fileName: String) -> String? {
        var fileName = fileName
        guard url.isFileURL else {
            guard !fileNames.contains(url.lastPathComponent) else { return nil }
            if !url.deletingPathExtension().lastPathComponent.isEmpty { fileName = url.deletingPathExtension().lastPathComponent }
            fileName += "." + (url.pathExtension.isEmpty ? "html" : url.pathExtension)
            let filenamePath = NSTemporaryDirectory() + fileName

            do {
                let downloadedContent = try Data(contentsOf: url)
                guard !FileManager.default.fileExists(atPath: filenamePath) else { return nil }
                try downloadedContent.write(to: URL(fileURLWithPath: filenamePath))
            } catch { print(error); return nil }
            return fileName
        }

        let filenamePath = NSTemporaryDirectory() + fileName

        try? FileManager.default.removeItem(atPath: filenamePath)

        do {
            try FileManager.default.copyItem(atPath: url.path, toPath: filenamePath)

            let attr = try FileManager.default.attributesOfItem(atPath: filenamePath)
            guard !attr.isEmpty else { return nil }
            return fileName
        } catch { return nil }
    }

    // Data
    func getItem(data: Data, fileName: String, provider: NSItemProvider) -> String? {
        guard !data.isEmpty else { return nil }
        var fileName = fileName

        if let url = URL(string: fileName), !url.pathExtension.isEmpty {
            fileName = url.lastPathComponent
        } else if let name = provider.suggestedName {
            fileName = name
        } else if let ext = provider.registeredTypeIdentifiers.last?.split(separator: ".").last {
            fileName += "." + ext
        } // else: no file information, use default name without ext

        // when sharing images in safari only data is retuned.
        // also, when sharing option "Automatic" is slected extension will return both raw data and a url, which will be downloaded, causing the image to appear twice with different names
        if let image = UIImage(data: data) {
            return getItem(image: image, fileName: fileName)
        }

        let filenamePath = NSTemporaryDirectory() + fileName
        FileManager.default.createFile(atPath: filenamePath, contents: data, attributes: nil)
        return fileName
    }

    // String
    func getItem(string: String, fileName: String) -> String? {
        guard !string.isEmpty else { return nil }
        let filenamePath = NSTemporaryDirectory() + fileName + ".txt"
        FileManager.default.createFile(atPath: filenamePath, contents: string.data(using: String.Encoding.utf8), attributes: nil)
        return fileName
    }
}

extension NSItemProvider {
    var typeIdentifier: String {
        if hasItemConformingToTypeIdentifier("public.url") { return "public.url" } else
        if hasItemConformingToTypeIdentifier(UTType.item.identifier as String) { return UTType.item.identifier as String } else { return "" }
    }
}
