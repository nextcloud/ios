//
//  NCShareExtension+Files.swift
//  Share
//
//  Created by Henrik Storch on 29.12.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation

extension NCShareExtension {

    @objc func reloadDatasource(withLoadFolder: Bool) {

        layoutForView = NCUtility.shared.getLayoutForView(key: keyLayout, serverUrl: serverUrl)

        let metadatasSource = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true", activeAccount.account, serverUrl))
        self.dataSource = NCDataSource(
            metadatasSource: metadatasSource,
            sort: layoutForView?.sort,
            ascending: layoutForView?.ascending,
            directoryOnTop: layoutForView?.directoryOnTop,
            favoriteOnTop: true,
            filterLivePhoto: true)

        if withLoadFolder {
            loadFolder()
        } else {
            self.refreshControl.endRefreshing()
        }

        collectionView.reloadData()
    }

    func createFolder(with fileName: String) {

        NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: activeAccount.account, urlBase: activeAccount.urlBase) { errorCode, errorDescription in

            DispatchQueue.main.async {
                if errorCode == 0 {

                    self.serverUrl += "/" + fileName
                    self.reloadDatasource(withLoadFolder: true)
                    self.setNavigationBar(navigationTitle: fileName)

                } else {
                    self.showAlert(title: "_error_createsubfolders_upload_", description: errorDescription)
                }
            }
        }
    }

    func loadFolder() {

        networkInProgress = true
        collectionView.reloadData()

        NCNetworking.shared.readFolder(serverUrl: serverUrl, account: activeAccount.account) { _, metadataFolder, _, _, _, _, errorCode, errorDescription in

            DispatchQueue.main.async {
                if errorCode != 0 {
                    self.showAlert(description: errorDescription)
                }
                self.networkInProgress = false
                self.metadataFolder = metadataFolder
                self.reloadDatasource(withLoadFolder: false)
            }
        }
    }

    func getFilesExtensionContext(completion: @escaping (_ filesName: [String]) -> Void) {

        var itemsProvider: [NSItemProvider] = []
        var filesName: [String] = []
        var conuter = 0
        let dateFormatter = DateFormatter()

        // ----------------------------------------------------------------------------------------

        // Image
        func getItem(image: UIImage, fileNameOriginal: String?) {

            var fileName: String = ""

            if let pngImageData = image.pngData() {

                if fileNameOriginal != nil {
                    fileName = fileNameOriginal!
                } else {
                    fileName = "\(dateFormatter.string(from: Date()))\(conuter).png"
                }

                let filenamePath = NSTemporaryDirectory() + fileName

                if (try? pngImageData.write(to: URL(fileURLWithPath: filenamePath), options: [.atomic])) != nil {
                    filesName.append(fileName)
                }
            }
        }

        // URL
        func getItem(url: NSURL, fileNameOriginal: String?) {

            guard let path = url.path else { return }

            var fileName: String = ""

            if fileNameOriginal != nil {
                fileName = fileNameOriginal!
            } else {
                if let ext = url.pathExtension {
                    fileName = "\(dateFormatter.string(from: Date()))\(conuter)." + ext
                }
            }

            let filenamePath = NSTemporaryDirectory() + fileName

            do {
                try FileManager.default.removeItem(atPath: filenamePath)
            } catch { }

            do {
                try FileManager.default.copyItem(atPath: path, toPath: filenamePath)

                do {
                    let attr = try FileManager.default.attributesOfItem(atPath: filenamePath) as NSDictionary?

                    if let xattr = attr {
                        if xattr.fileSize() > 0 {
                            filesName.append(fileName)
                        }
                    }

                } catch { }
            } catch { }
        }

        // Data
        func getItem(data: Data, fileNameOriginal: String?, description: String) {

            var fileName: String = ""

            if !data.isEmpty {

                if fileNameOriginal != nil {
                    fileName = fileNameOriginal!
                } else {
                    let fullNameArr = description.components(separatedBy: "\"")
                    let fileExtArr = fullNameArr[1].components(separatedBy: ".")
                    let pathExtention = (fileExtArr[fileExtArr.count - 1]).uppercased()
                    fileName = "\(dateFormatter.string(from: Date()))\(conuter).\(pathExtention)"
                }

                let filenamePath = NSTemporaryDirectory() + fileName
                FileManager.default.createFile(atPath: filenamePath, contents: data, attributes: nil)
                filesName.append(fileName)
            }
        }

        // String
        func getItem(string: NSString, fileNameOriginal: String?) {

            var fileName: String = ""

            if string.length > 0 {

                fileName = "\(dateFormatter.string(from: Date()))\(conuter).txt"
                let filenamePath = NSTemporaryDirectory() + "\(dateFormatter.string(from: Date()))\(conuter).txt"
                FileManager.default.createFile(atPath: filenamePath, contents: string.data(using: String.Encoding.utf8.rawValue), attributes: nil)
                filesName.append(fileName)
            }
        }

        // ----------------------------------------------------------------------------------------

        guard let inputItems: [NSExtensionItem] = extensionContext?.inputItems as? [NSExtensionItem] else {
            return completion(filesName)
        }

        for item: NSExtensionItem in inputItems {
            if let attachments = item.attachments {
                if attachments.isEmpty { continue }
                for itemProvider in attachments {
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeItem as String) || itemProvider.hasItemConformingToTypeIdentifier("public.url") {
                        itemsProvider.append(itemProvider)
                    }
                }
            }
        }

        CCUtility.emptyTemporaryDirectory()
        dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss-"

        for itemProvider in itemsProvider {

            var typeIdentifier = ""
            if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeItem as String) { typeIdentifier = kUTTypeItem as String }
            if itemProvider.hasItemConformingToTypeIdentifier("public.url") { typeIdentifier = "public.url" }

            itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil, completionHandler: {item, error -> Void in

                if error == nil {

                    var fileNameOriginal: String?

                    if let url = item as? NSURL {
                        if FileManager.default.fileExists(atPath: url.path ?? "") {
                            fileNameOriginal = url.lastPathComponent!
                        } else if url.scheme?.lowercased().contains("http") == true {
                            fileNameOriginal = "\(dateFormatter.string(from: Date()))\(conuter).html"
                        } else {
                            fileNameOriginal = "\(dateFormatter.string(from: Date()))\(conuter)"
                        }
                    }

                    if let image = item as? UIImage {
                       getItem(image: image, fileNameOriginal: fileNameOriginal)
                    }

                    if let url = item as? URL {
                        getItem(url: url as NSURL, fileNameOriginal: fileNameOriginal)
                    }

                    if let data = item as? Data {
                        getItem(data: data, fileNameOriginal: fileNameOriginal, description: itemProvider.description)
                    }

                    if let string = item as? NSString {
                        getItem(string: string, fileNameOriginal: fileNameOriginal)
                    }
                }

                conuter += 1
                if conuter == itemsProvider.count {
                    completion(filesName)
                }
            })
        }
    }
}
