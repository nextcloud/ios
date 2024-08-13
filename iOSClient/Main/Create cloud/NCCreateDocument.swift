//
//  NCCreateDocument.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 22/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
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

import Foundation
import UIKit
import NextcloudKit

class NCCreateDocument: NSObject {
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utility = NCUtility()

    func createDocument(controller: NCMainTabBarController, fileNamePath: String, fileName: String, editorId: String, creatorId: String? = nil, templateId: String) {
        guard let viewController = controller.currentViewController() else { return }
        var UUID = NSUUID().uuidString
        UUID = "TEMP" + UUID.replacingOccurrences(of: "-", with: "")
        var options = NKRequestOptions()
        let serverUrl = controller.currentServerUrl()

        if let creatorId, (editorId == NCGlobal.shared.editorText || editorId == NCGlobal.shared.editorOnlyoffice) {
            if editorId == NCGlobal.shared.editorOnlyoffice {
                options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentOnlyOffice())
            } else if editorId == NCGlobal.shared.editorText {
                options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentNCText())
            }

            NextcloudKit.shared.NCTextCreateFile(fileNamePath: fileNamePath, editorId: editorId, creatorId: creatorId, templateId: templateId, account: appDelegate.account, options: options) { account, url, _, error in
                guard error == .success, account == self.appDelegate.account, let url = url else {
                    NCContentPresenter().showError(error: error)
                    return
                }
                let contentType = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileName, mimeType: "", directory: false).mimeType
                let metadata = NCManageDatabase.shared.createMetadata(account: self.appDelegate.account, user: self.appDelegate.user, userId: self.appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: UUID, serverUrl: serverUrl, urlBase: self.appDelegate.urlBase, url: url, contentType: contentType)

                NCViewer().view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: nil)
            }

        } else if editorId == NCGlobal.shared.editorCollabora {

            NextcloudKit.shared.createRichdocuments(path: fileNamePath, templateId: templateId, account: appDelegate.account) { account, url, _, error in
                guard error == .success, account == self.appDelegate.account, let url = url else {
                    NCContentPresenter().showError(error: error)
                    return
                }
                let contentType = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileName, mimeType: "", directory: false).mimeType
                let metadata = NCManageDatabase.shared.createMetadata(account: self.appDelegate.account, user: self.appDelegate.user, userId: self.appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: UUID, serverUrl: serverUrl, urlBase: self.appDelegate.urlBase, url: url, contentType: contentType)

                NCViewer().view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: nil)
            }
        }
    }

    func getTemplate(editorId: String, templateId: String) async -> (templates: [NKEditorTemplates], selectedTemplate: NKEditorTemplates, ext: String) {
        var templates: [NKEditorTemplates] = []
        var selectedTemplate = NKEditorTemplates()
        var ext: String = ""

        if editorId == NCGlobal.shared.editorText || editorId == NCGlobal.shared.editorOnlyoffice {
            var options = NKRequestOptions()
            if editorId == NCGlobal.shared.editorOnlyoffice {
                options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentOnlyOffice())
            } else if editorId == NCGlobal.shared.editorText {
                options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentNCText())
            }

            let results = await textGetListOfTemplates(account:appDelegate.account, options: options)
            if results.error == .success {
                for template in results.templates {
                    let temp = NKEditorTemplates()
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
                let temp = NKEditorTemplates()
                temp.identifier = ""
                if editorId == NCGlobal.shared.editorText {
                    temp.ext = "md"
                } else if editorId == NCGlobal.shared.editorOnlyoffice && templateId == NCGlobal.shared.templateDocument {
                    temp.ext = "docx"
                } else if editorId == NCGlobal.shared.editorOnlyoffice && templateId == NCGlobal.shared.templateSpreadsheet {
                    temp.ext = "xlsx"
                } else if editorId == NCGlobal.shared.editorOnlyoffice && templateId == NCGlobal.shared.templatePresentation {
                    temp.ext = "pptx"
                }
                temp.name = "Empty"
                temp.preview = ""
                templates.append(temp)
                selectedTemplate = temp
                ext = temp.ext
            }
        }

        if editorId == NCGlobal.shared.editorCollabora {
            let results = await getTemplatesRichdocuments(typeTemplate: templateId, account: appDelegate.account)
            if results.error == .success {
                for template in results.templates! {
                    let temp = NKEditorTemplates()
                    temp.identifier = "\(template.templateId)"
                    temp.delete = template.delete
                    temp.ext = template.ext
                    temp.name = template.name
                    temp.preview = template.preview
                    temp.type = template.type
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

    // MARK: - NextcloudKit async/await

    func textGetListOfTemplates(account: String, options: NKRequestOptions = NKRequestOptions()) async -> (account: String, templates: [NKEditorTemplates], data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.NCTextGetListOfTemplates(account: account) { account, templates, data, error in
                continuation.resume(returning: (account: account, templates: templates, data: data, error: error))
            }
        })
    }

    func getTemplatesRichdocuments(typeTemplate: String, account: String, options: NKRequestOptions = NKRequestOptions()) async -> (account: String, templates: [NKRichdocumentsTemplate]?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getTemplatesRichdocuments(typeTemplate: typeTemplate, account: account, options: options) { account, templates, data, error in
                continuation.resume(returning: (account: account, templates: templates, data: data, error: error))
            }
        })
    }
}
