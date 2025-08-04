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
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared

    func createDocument(controller: NCMainTabBarController, fileNamePath: String, fileName: String, editorId: String, creatorId: String? = nil, templateId: String, account: String) {
        let session = NCSession.shared.getSession(account: account)
        guard let viewController = controller.currentViewController() else { return }
        var UUID = NSUUID().uuidString
        UUID = "TEMP" + UUID.replacingOccurrences(of: "-", with: "")
        var options = NKRequestOptions()
        let serverUrl = controller.currentServerUrl()

        if let creatorId, editorId == "text" || editorId == "onlyoffice" {
            if editorId == "onlyoffice" {
                options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentOnlyOffice())
            } else if editorId == "text" {
                options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentNCText())
            }

            NextcloudKit.shared.textCreateFile(fileNamePath: fileNamePath, editorId: editorId, creatorId: creatorId, templateId: templateId, account: account, options: options) { _, url, _, error in
                guard error == .success, let url else {
                    return NCContentPresenter().showError(error: error)
                }

                self.database.createMetadata(fileName: fileName,
                                             ocId: UUID,
                                             serverUrl: serverUrl,
                                             url: url,
                                             session: session,
                                             sceneIdentifier: controller.sceneIdentifier) { metadata in
                    NCViewer().getViewerController(metadata: metadata, delegate: viewController) { vc in
                        guard let vc else {
                            return
                        }
                        viewController.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            }

        } else if editorId == "collabora" {

            NextcloudKit.shared.createRichdocuments(path: fileNamePath, templateId: templateId, account: account) { returnedAccount, url, _, error in
                guard error == .success, let url else {
                    return NCContentPresenter().showError(error: error)
                }
                if account == returnedAccount {
                    self.database.createMetadata(fileName: fileName,
                                                 ocId: UUID,
                                                 serverUrl: serverUrl,
                                                 url: url,
                                                 session: session,
                                                 sceneIdentifier: controller.sceneIdentifier) { metadata in
                        NCViewer().getViewerController(metadata: metadata, delegate: viewController) { vc in
                            guard let vc else {
                                return
                            }
                            viewController.navigationController?.pushViewController(vc, animated: true)
                        }
                    }
                }
            }
        }
    }

    func getTemplate(editorId: String, templateId: String, account: String) async -> (templates: [NKEditorTemplate], selectedTemplate: NKEditorTemplate, ext: String) {
        var templates: [NKEditorTemplate] = []
        var selectedTemplate = NKEditorTemplate()
        var ext: String = ""

        if editorId == "text" || editorId == "onlyoffice" {
            var options = NKRequestOptions()
            if editorId == "onlyoffice" {
                options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentOnlyOffice())
            } else if editorId == "text" {
                options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentNCText())
            }

            let results = await NextcloudKit.shared.textGetListOfTemplatesAsync(account: account, options: options)
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
                if editorId == "text" {
                    temp.ext = "md"
                } else if editorId == "onlyoffice" && templateId == "document" {
                    temp.ext = "docx"
                } else if editorId == "onlyoffice" && templateId == "spreadsheet" {
                    temp.ext = "xlsx"
                } else if editorId == "onlyoffice" && templateId == "presentation" {
                    temp.ext = "pptx"
                }
                temp.name = "Empty"
                temp.preview = ""
                templates.append(temp)
                selectedTemplate = temp
                ext = temp.ext
            }
        }

        if editorId == "collabora" {
            let results = await NextcloudKit.shared.getTemplatesRichdocumentsAsync(typeTemplate: templateId, account: account)
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
}
