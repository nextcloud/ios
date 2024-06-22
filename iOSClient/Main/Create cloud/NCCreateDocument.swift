//
//  NCCreateDocument.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 22/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import NextcloudKit

class NCCreateDocument: NSObject {
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utility = NCUtility()

    func getTemplate(editorId: String, typeTemplate: String) async -> (templates: [NKEditorTemplates], selectedTemplate: NKEditorTemplates?, ext: String) {
        var templates: [NKEditorTemplates] = []
        var selectedTemplate: NKEditorTemplates?
        var ext: String = ""

        if editorId == NCGlobal.shared.editorText || editorId == NCGlobal.shared.editorOnlyoffice {
            var options = NKRequestOptions()
            if editorId == NCGlobal.shared.editorOnlyoffice {
                options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentOnlyOffice())
            } else if editorId == NCGlobal.shared.editorText {
                options = NKRequestOptions(customUserAgent: NCUtility().getCustomUserAgentNCText())
            }

            let results = await TextGetListOfTemplates(options: options)
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
                } else if editorId == NCGlobal.shared.editorOnlyoffice && typeTemplate == NCGlobal.shared.templateDocument {
                    temp.ext = "docx"
                } else if editorId == NCGlobal.shared.editorOnlyoffice && typeTemplate == NCGlobal.shared.templateSpreadsheet {
                    temp.ext = "xlsx"
                } else if editorId == NCGlobal.shared.editorOnlyoffice && typeTemplate == NCGlobal.shared.templatePresentation {
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
            let results = await getTemplatesRichdocuments(typeTemplate: typeTemplate)
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

    // MARK: -

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

            NextcloudKit.shared.NCTextCreateFile(fileNamePath: fileNamePath, editorId: NCGlobal.shared.editorText, creatorId: creatorId, templateId: NCGlobal.shared.templateDocument, options: options) { account, url, _, error in
                guard error == .success, account == self.appDelegate.account, let url = url else {
                    NCContentPresenter().showError(error: error)
                    return
                }
                let contentType = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileName, mimeType: "", directory: false).mimeType
                let metadata = NCManageDatabase.shared.createMetadata(account: self.appDelegate.account, user: self.appDelegate.user, userId: self.appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: UUID, serverUrl: serverUrl, urlBase: self.appDelegate.urlBase, url: url, contentType: contentType)

                NCViewer().view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: nil)
            }

        } else if editorId == NCGlobal.shared.editorCollabora {

            NextcloudKit.shared.createRichdocuments(path: fileNamePath, templateId: templateId) { account, url, _, error in
                guard error == .success, account == self.appDelegate.account, let url = url else {
                    NCContentPresenter().showError(error: error)
                    return
                }

                /*
                self.dismiss(animated: true, completion: {
                    let newFileName = (fileName as NSString).deletingPathExtension + "." + self.fileNameExtension
                    let metadata = NCManageDatabase.shared.createMetadata(account: self.appDelegate.account, user: self.appDelegate.user, userId: self.appDelegate.userId, fileName: newFileName, fileNameView: newFileName, ocId: UUID, serverUrl: self.serverUrl, urlBase: self.appDelegate.urlBase, url: url, contentType: "")
                    if let viewController = self.controller?.currentViewController() {
                        NCViewer().view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: nil)
                    }
               })
               */
            }
        }
    }

    // MARK: -

    func TextGetListOfTemplates(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, templates: [NKEditorTemplates], data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.NCTextGetListOfTemplates { account, templates, data, error in
                continuation.resume(returning: (account: account, templates: templates, data: data, error: error))
            }
        })
    }

    func getTemplatesRichdocuments(typeTemplate: String, options: NKRequestOptions = NKRequestOptions()) async -> (account: String, templates: [NKRichdocumentsTemplate]?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getTemplatesRichdocuments(typeTemplate: typeTemplate, options: options) { account, templates, data, error in
                continuation.resume(returning: (account: account, templates: templates, data: data, error: error))
            }
        })
    }
}
