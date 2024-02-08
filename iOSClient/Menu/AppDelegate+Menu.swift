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

    func toggleMenu(viewController: UIViewController) {

        var actions: [NCMenuAction] = []
        let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
        let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: appDelegate.account)
        let isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: appDelegate.activeServerUrl, userBase: appDelegate)
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, appDelegate.activeServerUrl))

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_photos_videos_", comment: ""), icon: UIImage(named: "file_photo")!.image(color: UIColor.systemGray, size: 50), action: { _ in
                    NCAskAuthorization().askAuthorizationPhotoLibrary(viewController: viewController) { hasPermission in
                        if hasPermission {NCPhotosPickerViewController(viewController: viewController, maxSelectedAssets: 0, singleSelectedMode: false)
                        }
                    }
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_upload_file_", comment: ""), icon: UIImage(named: "file")!.image(color: UIColor.systemGray, size: 50), action: { _ in
                    if let tabBarController = self.window?.rootViewController as? UITabBarController {
                        self.documentPickerViewController = NCDocumentPickerViewController(tabBarController: tabBarController, isViewerMedia: false, allowsMultipleSelection: true)
                    }
                }
            )
        )

        if NextcloudKit.shared.isNetworkReachable() && directEditingCreators != nil && directEditingCreators!.contains(where: { $0.editor == NCGlobal.shared.editorText}) && !isDirectoryE2EE {
            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorText})!

            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_nextcloudtext_document_", comment: ""), icon: UIImage(named: "file_txt")!.image(color: UIColor.systemGray, size: 50), action: { _ in

                    let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorText})!
                    let fileName = NCUtilityFileSystem().createFileName("Untitled.txt", serverUrl: self.activeServerUrl, account: self.account)

                    let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: appDelegate.activeServerUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)
                    self.createTextDocument(fileNamePath: fileNamePath, fileName: String(describing: fileName), creatorId: directEditingCreator.identifier)
                })
            )
        }

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_scans_document_", comment: ""), icon: NCUtility().loadImage(named: "doc.text.viewfinder"), action: { _ in
                    if let viewController = appDelegate.window?.rootViewController {
                        NCDocumentCamera.shared.openScannerDocument(viewController: viewController)
                    }
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_create_voice_memo_", comment: ""), icon: UIImage(named: "microphone")!.image(color: UIColor.systemGray, size: 50), action: { _ in
                    NCAskAuthorization().askAuthorizationAudioRecord(viewController: viewController) { hasPermission in
                        if hasPermission {
                            let fileName = NCUtilityFileSystem().createFileNameDate(NSLocalizedString("_voice_memo_filename_", comment: ""), ext: "m4a")
                            if let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as? NCAudioRecorderViewController {

                                viewController.delegate = self
                                viewController.createRecorder(fileName: fileName)
                                viewController.modalTransitionStyle = .crossDissolve
                                viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext

                                appDelegate.window?.rootViewController?.present(viewController, animated: true, completion: nil)
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
                             guard !appDelegate.activeServerUrl.isEmpty else { return }
                             let alertController = UIAlertController.createFolder(serverUrl: appDelegate.activeServerUrl, urlBase: appDelegate)
                             appDelegate.window?.rootViewController?.present(alertController, animated: true, completion: nil)
                         }
                        )
        )

        // Folder encrypted
        if !isDirectoryE2EE && NCKeychain().isEndToEndEnabled(account: appDelegate.account) {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_create_folder_e2ee_", comment: ""),
                             icon: UIImage(named: "folderEncrypted")!.image(color: NCBrandColor.shared.brandElement, size: 50),
                             action: { _ in
                                 guard !appDelegate.activeServerUrl.isEmpty else { return }
                                 let alertController = UIAlertController.createFolder(serverUrl: appDelegate.activeServerUrl, urlBase: appDelegate, markE2ee: true)
                                 appDelegate.window?.rootViewController?.present(alertController, animated: true, completion: nil)
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
                        if let viewController = self.activeViewController {
                            if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", appDelegate.account, appDelegate.activeServerUrl, NCGlobal.shared.fileNameRichWorkspace.lowercased())) == nil {
                                richWorkspaceCommon.createViewerNextcloudText(serverUrl: appDelegate.activeServerUrl, viewController: viewController)
                            } else {
                                richWorkspaceCommon.openViewerNextcloudText(serverUrl: appDelegate.activeServerUrl, viewController: viewController)
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
                            viewController.editorId = NCGlobal.shared.editorOnlyoffice
                            viewController.creatorId = directEditingCreator.identifier
                            viewController.typeTemplate = NCGlobal.shared.templateDocument
                            viewController.serverUrl = appDelegate.activeServerUrl
                            viewController.titleForm = NSLocalizedString("_create_new_document_", comment: "")

                            appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
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
                            viewController.editorId = NCGlobal.shared.editorOnlyoffice
                            viewController.creatorId = directEditingCreator.identifier
                            viewController.typeTemplate = NCGlobal.shared.templateSpreadsheet
                            viewController.serverUrl = appDelegate.activeServerUrl
                            viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")

                            appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
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
                            viewController.editorId = NCGlobal.shared.editorOnlyoffice
                            viewController.creatorId = directEditingCreator.identifier
                            viewController.typeTemplate = NCGlobal.shared.templatePresentation
                            viewController.serverUrl = appDelegate.activeServerUrl
                            viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")

                            appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
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

                            let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorText})!
                            let fileName = NCUtilityFileSystem().createFileName("Untitled.txt", serverUrl: self.activeServerUrl, account: self.account)

                            let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: appDelegate.activeServerUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)
                            self.createTextDocument(fileNamePath: fileNamePath, fileName: String(describing: fileName), creatorId: directEditingCreator.identifier)
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
                                viewController.editorId = NCGlobal.shared.editorCollabora
                                viewController.typeTemplate = NCGlobal.shared.templateSpreadsheet
                                viewController.serverUrl = appDelegate.activeServerUrl
                                viewController.titleForm = NSLocalizedString("_create_new_spreadsheet_", comment: "")

                                appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
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
                                viewController.editorId = NCGlobal.shared.editorCollabora
                                viewController.typeTemplate = NCGlobal.shared.templatePresentation
                                viewController.serverUrl = appDelegate.activeServerUrl
                                viewController.titleForm = NSLocalizedString("_create_new_presentation_", comment: "")

                                appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
                            }
                        }
                    )
                )
            }
        }

        viewController.presentMenu(with: actions)
    }

    func createTextDocument(fileNamePath: String, fileName: String, creatorId: String) {
        var UUID = NSUUID().uuidString
        UUID = "TEMP" + UUID.replacingOccurrences(of: "-", with: "")

        var options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentNCText())

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

            let metadata = NCManageDatabase.shared.createMetadata(account: self.account, user: self.user, userId: self.userId, fileName: fileName, fileNameView: fileName, ocId: UUID, serverUrl: self.activeServerUrl, urlBase: self.urlBase, url: url, contentType: results.mimeType)
            if let viewController = self.activeViewController {
                NCViewer().view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: nil)
            }
        }
    }
}
