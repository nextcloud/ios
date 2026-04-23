// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift
import LucidBanner

extension NCCollectionViewCommon: UIEditMenuInteractionDelegate {
    func openMenuItems(with objectId: String?, gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else { return }
        guard !serverUrl.isEmpty else { return }
        guard let editMenuInteraction else { return }

        let touchPoint = gestureRecognizer.location(in: collectionView)

        currentMenuObjectId = objectId
        currentMenuPoint = touchPoint

        let configuration = UIEditMenuConfiguration(identifier: objectId as NSString?, sourcePoint: touchPoint)
        editMenuInteraction.presentEditMenu(with: configuration)
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
        var actions: [UIMenuElement] = []

        if !UIPasteboard.general.items.isEmpty,
           !(metadataFolder?.e2eEncrypted ?? false) {
            let pasteAction = UIAction(
                title: NSLocalizedString("_paste_file_", comment: "")
            ) { [weak self] _ in
                self?.pasteFilesMenu()
            }
            actions.append(pasteAction)
        }

        return actions.isEmpty ? nil : UIMenu(children: actions)
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction, targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
        CGRect(x: currentMenuPoint.x, y: currentMenuPoint.y, width: 1, height: 1)
    }

    @objc func pasteFilesMenu() {
        Task {@MainActor in
            guard let tblAccount = await NCManageDatabase.shared.getTableAccountAsync(account: session.account) else {
                return
            }
            let bannerResults = showHudBanner(
                windowScene: windowScene,
                title: "_upload_in_progress_")

            for (index, items) in UIPasteboard.general.items.enumerated() {
                for item in items {
                    let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
                    let results = NKFilePropertyResolver().resolve(inUTI: item.key, capabilities: capabilities)
                    guard let data = UIPasteboard.general.data(forPasteboardType: item.key,
                                                               inItemSet: IndexSet([index]))?.first
                    else {
                        continue
                    }
                    let fileName = results.name + "_" + NCPreferences().incrementalNumber + "." + results.ext
                    let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: serverUrl, fileName: fileName)
                    let ocIdUpload = UUID().uuidString
                    let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(
                        ocIdUpload,
                        fileName: fileName,
                        userId: tblAccount.userId,
                        urlBase: tblAccount.urlBase
                    )
                    do {
                        try data.write(to: URL(fileURLWithPath: fileNameLocalPath))
                    } catch {
                        continue
                    }

                    let resultsUpload = await NCNetworking.shared.uploadFile(account: session.account,
                                                                             fileNameLocalPath: fileNameLocalPath,
                                                                             serverUrlFileName: serverUrlFileName) { _ in
                    } progressHandler: { _, _, fractionCompleted in
                        Task {@MainActor in
                            bannerResults.banner?.update(
                                payload: LucidBannerPayload.Update(progress: fractionCompleted),
                                for: bannerResults.token
                            )
                        }
                    }

                    if resultsUpload.error == .success,
                       let etag = resultsUpload.etag,
                       let ocId = resultsUpload.ocId {
                        let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(
                            ocId,
                            fileName: fileName,
                            userId: tblAccount.userId,
                            urlBase: tblAccount.urlBase)
                        self.utilityFileSystem.moveFile(atPath: fileNameLocalPath, toPath: toPath)
                        NCManageDatabase.shared.addLocalFile(
                            account: session.account,
                            etag: etag,
                            ocId: ocId,
                            fileName: fileName)
                        Task {
                            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                                delegate.transferReloadDataSource(serverUrl: self.serverUrl, requestData: true, status: nil)
                            }
                        }
                    } else {
                        Task {
                            await showErrorBanner(windowScene: windowScene,
                                                  text: resultsUpload.error.errorDescription,
                                                  errorCode: resultsUpload.error.errorCode)
                        }
                    }
                }
            }

            if let banner = bannerResults.banner {
                banner.dismiss()
            }
        }
    }

}
