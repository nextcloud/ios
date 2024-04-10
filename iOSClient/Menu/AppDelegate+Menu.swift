//
//  AppDelegate+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//
//  Author Philippe Weidmann <philippe.weidmann@infomaniak.com>
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import FloatingPanel
import NextcloudKit

extension AppDelegate {

    func toggleMenu(mainTabBarController: NCMainTabBarController) {
        var actions: [NCMenuAction] = []
        let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
        let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: appDelegate.account)
        let serverUrl = mainTabBarController.serverUrl ?? NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        let isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, userBase: appDelegate)
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_photos_videos_", comment: ""), icon: UIImage(named: "file_photo")!.image(color: UIColor.systemGray, size: 50), action: { _ in
                    NCAskAuthorization().askAuthorizationPhotoLibrary(viewController: mainTabBarController) { hasPermission in
                        if hasPermission {NCPhotosPickerViewController(mainTabBarController: mainTabBarController, maxSelectedAssets: 0, singleSelectedMode: false)
                        }
                    }
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_file_", comment: ""), icon: UIImage(named: "file")!.image(color: UIColor.systemGray, size: 50), action: { _ in
                    mainTabBarController.documentPickerViewController = NCDocumentPickerViewController(mainTabBarController: mainTabBarController, isViewerMedia: false, allowsMultipleSelection: true)
                }
            )
        )

        if NextcloudKit.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCGlobal.shared.editorText}) && !isDirectoryE2EE {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""), icon: UIImage(named: "file_txt")!.image(color: UIColor.systemGray, size: 50), action: { _ in
                    let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorText})!

                    Task {
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + ".md", account: appDelegate.account, serverUrl: serverUrl)

                        let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)
                        self.createTextDocument(mainTabBarController: mainTabBarController, fileNamePath: fileNamePath, fileName: String(describing: fileName), creatorId: directEditingCreator.identifier)
                    }
                })
            )
        }

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_scans_document_", comment: ""), icon: NCUtility().loadImage(named: "doc.text.viewfinder"), action: { _ in
                    NCDocumentCamera.shared.openScannerDocument(viewController: mainTabBarController)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_create_voice_memo_", comment: ""), icon: UIImage(named: "microphone")!.image(color: UIColor.systemGray, size: 50), action: { _ in
                    NCAskAuthorization().askAuthorizationAudioRecord(viewController: mainTabBarController) { hasPermission in
                        if hasPermission {
                            if let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as? NCAudioRecorderViewController {
                                viewController.serverUrl = serverUrl
                                viewController.modalTransitionStyle = .crossDissolve
                                viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
                                mainTabBarController.present(viewController, animated: true, completion: nil)
                            }
                        }
                    }
                }
            )
        )

        if NCKeychain().isEndToEndEnabled(account: appDelegate.account) {
            actions.append(.seperator(order: 0))
        }

        let titleCreateFolder = isDirectoryE2EE ? NSLocalizedString("_create_folder_e2ee_", comment: "") : NSLocalizedString("_create_folder_", comment: "")
        let imageCreateFolder = isDirectoryE2EE ? UIImage(named: "folderEncrypted")! : UIImage(named: "folder")!
        actions.append(
            NCMenuAction(title: titleCreateFolder,
                         icon: imageCreateFolder.image(color: NCBrandColor.shared.brandElement, size: 50), action: { _ in
                             let alertController = UIAlertController.createFolder(serverUrl: serverUrl, urlBase: appDelegate)
                             mainTabBarController.present(alertController, animated: true, completion: nil)
                         }
                        )
        )

        // Folder encrypted
        if !isDirectoryE2EE && NCKeychain().isEndToEndEnabled(account: appDelegate.account) {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_folder_e2ee_", comment: ""),
                             icon: UIImage(named: "folderEncrypted")!.image(color: NCBrandColor.shared.brandElement, size: 50),
                             action: { _ in
                                 let alertController = UIAlertController.createFolder(serverUrl: serverUrl, urlBase: appDelegate, markE2ee: true)
                                 mainTabBarController.present(alertController, animated: true, completion: nil)
                             })
            )
        }

        if NCKeychain().isEndToEndEnabled(account: appDelegate.account) {
            actions.append(.seperator(order: 0))
        }

        if NCGlobal.shared.capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion18 && directory?.richWorkspace == nil && !isDirectoryE2EE && NextcloudKit.shared.isNetworkReachable() {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_add_folder_info_", comment: ""), icon: UIImage(named: "addFolderInfo")!.image(color: UIColor.systemGray, size: 50), action: { _ in
                        let richWorkspaceCommon = NCRichWorkspaceCommon()
                        if let viewController = mainTabBarController.viewController {
                            if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", appDelegate.account, serverUrl, NCGlobal.shared.fileNameRichWorkspace.lowercased())) == nil {
                                richWorkspaceCommon.createViewerNextcloudText(serverUrl: serverUrl, viewController: viewController)
                            } else {
                                richWorkspaceCommon.openViewerNextcloudText(serverUrl: serverUrl, viewController: viewController)
                            }
                        }
                    }
                )
            )
        }

        if NextcloudKit.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficeDocx}) && !isDirectoryE2EE {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficeDocx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_document_", comment: ""), icon: UIImage(named: "create_file_document")!, action: { _ in
                        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                            return
                        }
                        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                        if let viewController = (navigationController as? UINavigationController)?.topViewController as? NCCreateFormUploadDocuments {
                            viewController.mainTabBarController = mainTabBarController
                            viewController.editorId = NCGlobal.shared.editorOnlyoffice
                            viewController.creatorId = directEditingCreator.identifier
                            viewController.typeTemplate = NCGlobal.shared.templateDocument
                            viewController.serverUrl = serverUrl
                            viewController.titleForm = NSLocalizedString("_create_new_document_", comment: "")

                            mainTabBarController.present(navigationController, animated: true, completion: nil)
                        }
                    }
                )
            )
        }

        if NextcloudKit.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficeXlsx}) && !isDirectoryE2EE {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficeXlsx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), icon: UIImage(named: "create_file_xls")!, action: { _ in
                        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                            return
                        }
                        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                        if let viewController = (navigationController as? UINavigationController)?.topViewController as? NCCreateFormUploadDocuments {
                            viewController.mainTabBarController = mainTabBarController
                            viewController.editorId = NCGlobal.shared.editorOnlyoffice
                            viewController.creatorId = directEditingCreator.identifier
                            viewController.typeTemplate = NCGlobal.shared.templateSpreadsheet
                            viewController.serverUrl = serverUrl
                            viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")

                            mainTabBarController.present(navigationController, animated: true, completion: nil)
                        }
                    }
                )
            )
        }

        if NextcloudKit.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficePptx}) && !isDirectoryE2EE {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorOnlyoffice && $0.identifier == NCGlobal.shared.onlyofficePptx})!
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_create_new_presentation_", comment: ""), icon: UIImage(named: "create_file_ppt")!, action: { _ in
                        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                            return
                        }
                        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                        if let viewController = (navigationController as? UINavigationController)?.topViewController as? NCCreateFormUploadDocuments {
                            viewController.mainTabBarController = mainTabBarController
                            viewController.editorId = NCGlobal.shared.editorOnlyoffice
                            viewController.creatorId = directEditingCreator.identifier
                            viewController.typeTemplate = NCGlobal.shared.templatePresentation
                            viewController.serverUrl = serverUrl
                            viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")

                            mainTabBarController.present(navigationController, animated: true, completion: nil)
                        }
                    }
                )
            )
        }

        if NCGlobal.shared.capabilityRichdocumentsEnabled {
            if NextcloudKit.shared.isNetworkReachable() && !isDirectoryE2EE {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_document_", comment: ""), icon: UIImage(named: "create_file_document")!, action: { _ in
                            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                                return
                            }
                            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                            if let viewController = (navigationController as? UINavigationController)?.topViewController as? NCCreateFormUploadDocuments {
                                viewController.mainTabBarController = mainTabBarController
                                viewController.editorId = NCGlobal.shared.editorCollabora
                                viewController.typeTemplate = NCGlobal.shared.templateDocument
                                viewController.serverUrl = serverUrl
                                viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")

                                mainTabBarController.present(navigationController, animated: true, completion: nil)
                            }
                        }
                    )
                )

                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_spreadsheet_", comment: ""), icon: UIImage(named: "create_file_xls")!, action: { _ in
                            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                                return
                            }
                            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                            if let viewController = (navigationController as? UINavigationController)?.topViewController as? NCCreateFormUploadDocuments {
                                viewController.mainTabBarController = mainTabBarController
                                viewController.editorId = NCGlobal.shared.editorCollabora
                                viewController.typeTemplate = NCGlobal.shared.templateSpreadsheet
                                viewController.serverUrl = serverUrl
                                viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")

                                mainTabBarController.present(navigationController, animated: true, completion: nil)
                            }
                        }
                    )
                )

                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_create_new_presentation_", comment: ""), icon: UIImage(named: "create_file_ppt")!, action: { _ in
                            guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController() else {
                                return
                            }
                            navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                            if let viewController = (navigationController as? UINavigationController)?.topViewController as? NCCreateFormUploadDocuments {
                                viewController.mainTabBarController = mainTabBarController
                                viewController.editorId = NCGlobal.shared.editorCollabora
                                viewController.typeTemplate = NCGlobal.shared.templatePresentation
                                viewController.serverUrl = serverUrl
                                viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")

                                mainTabBarController.present(navigationController, animated: true, completion: nil)
                            }
                        }
                    )
                )
            }
        }

        mainTabBarController.presentMenu(with: actions)
    }

    func createTextDocument(mainTabBarController: NCMainTabBarController, fileNamePath: String, fileName: String, creatorId: String) {
        var UUID = NSUUID().uuidString
        UUID = "TEMP" + UUID.replacingOccurrences(of: "-", with: "")
        let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
        let serverUrl = mainTabBarController.serverUrl ?? NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        let options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentNCText())

        NextcloudKit.shared.NCTextCreateFile(fileNamePath: fileNamePath, editorId: NCGlobal.shared.editorText, creatorId: creatorId, templateId: NCGlobal.shared.templateDocument, options: options) { account, url, _, error in
            guard error == .success, account == self.account, let url = url else {
                NCContentPresenter().showError(error: error)
                return
            }

            var results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileName, mimeType: "", directory: false)
            // FIXME: iOS 12.0,* don't detect UTI text/markdown, text/x-markdown
            if results.mimeType.isEmpty {
                results.mimeType = "text/x-markdown"
            }

            let metadata = NCManageDatabase.shared.createMetadata(account: self.account, user: self.user, userId: self.userId, fileName: fileName, fileNameView: fileName, ocId: UUID, serverUrl: serverUrl, urlBase: self.urlBase, url: url, contentType: results.mimeType)
            if let viewController = mainTabBarController.viewController {
                NCViewer().view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: nil)
            }
        }
    }
}
