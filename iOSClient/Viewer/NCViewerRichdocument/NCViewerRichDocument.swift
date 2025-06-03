//
//  NCViewerRichdocument.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/09/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

import UIKit
@preconcurrency import WebKit
import NextcloudKit

class NCViewerRichDocument: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, NCSelectDelegate {
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    var webView = WKWebView()
    var bottomConstraint: NSLayoutConstraint?
    var documentController: UIDocumentInteractionController?
    var link: String = ""
    var metadata: tableMetadata = tableMetadata()
    var imageIcon: UIImage?

    var session: NCSession.Session {
        NCSession.shared.getSession(account: metadata.account)
    }

    var sceneIdentifier: String {
        (self.tabBarController as? NCMainTabBarController)?.sceneIdentifier ?? ""
    }

    // MARK: - View Life Cycle

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if !metadata.ocId.hasPrefix("TEMP") {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: NCImageCache.shared.getImageButtonMore(), style: .plain, target: self, action: #selector(openMenuMore(_:)))
        }
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.title = metadata.fileNameView

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let contentController = config.userContentController
        contentController.add(self, name: "RichDocumentsMobileInterface")

        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView.navigationDelegate = self
        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        webView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: 0).isActive = true
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        bottomConstraint = webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0)
        bottomConstraint?.isActive = true

        var request = URLRequest(url: URL(string: link)!)
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        let language = NSLocale.preferredLanguages[0] as String
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        webView.customUserAgent = userAgent

        webView.load(request)
    }

    deinit {
        print("dealloc")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.grabFocus), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRichdocumentGrabFocus), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NCNetworking.shared.addDelegate(self)

        NCActivityIndicator.shared.start(backgroundView: view)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NCNetworking.shared.removeDelegate(self)

        if let navigationController = self.navigationController {
            if !navigationController.viewControllers.contains(self) {
                let functionJS = "OCA.RichDocuments.documentsMain.onClose()"
                webView.evaluateJavaScript(functionJS) { _, _ in
                    print("close")
                }
            }
        }

        webView.configuration.userContentController.removeScriptMessageHandler(forName: "RichDocumentsMobileInterface")

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRichdocumentGrabFocus), object: nil)

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func viewUnload() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - NotificationCenter

    @objc func keyboardDidShow(notification: Notification) {
        guard let info = notification.userInfo else { return }
        guard let frameInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardFrame = frameInfo.cgRectValue
        let height = keyboardFrame.size.height
        bottomConstraint?.constant = -height
    }

    @objc func keyboardWillHide(notification: Notification) {
        bottomConstraint?.constant = 0
    }

    // MARK: - Action

    @objc private func openMenuMore(_ sender: Any?) {
        if imageIcon == nil { imageIcon = NCUtility().loadImage(named: "doc.text", colors: [NCBrandColor.shared.iconImageColor]) }
        NCViewer().toggleMenu(controller: self.tabBarController as? NCMainTabBarController, metadata: metadata, webView: true, imageIcon: imageIcon, sender: nil)
    }

    // MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "RichDocumentsMobileInterface" {
            if message.body as? String == "close" {
                viewUnload()
            }

            if message.body as? String == "insertGraphic" {
                let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
                if let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController,
                   let viewController = navigationController.topViewController as? NCSelect {

                    viewController.delegate = self
                    viewController.typeOfCommandView = .select
                    viewController.enableSelectFile = true
                    viewController.includeImages = true
                    viewController.type = ""
                    viewController.session = session

                    self.present(navigationController, animated: true, completion: nil)
                }
            }

            if message.body as? String == "share" {
                NCDownloadAction.shared.openShare(viewController: self, metadata: metadata, page: .sharing)
            }

            if let param = message.body as? [AnyHashable: Any] {

                if param["MessageName"] as? String == "downloadAs" {
                    if let values = param["Values"] as? [AnyHashable: Any] {
                        guard let type = values["Type"] as? String else { return }
                        guard let urlString = values["URL"] as? String else { return }
                        guard let url = URL(string: urlString) else { return }
                        let fileNameLocalPath = utilityFileSystem.directoryUserData + "/" + (metadata.fileName as NSString).deletingPathExtension

                        if type == "slideshow" {
                            if let browserWebVC = UIStoryboard(name: "NCBrowserWeb", bundle: nil).instantiateInitialViewController() as? NCBrowserWeb {

                                browserWebVC.urlBase = urlString
                                browserWebVC.isHiddenButtonExit = false
                                self.present(browserWebVC, animated: true)
                            }
                            return
                        } else {
                            // TYPE PRINT - DOWNLOAD
                            NCActivityIndicator.shared.start(backgroundView: view)
                            NextcloudKit.shared.download(serverUrlFileName: url, fileNameLocalPath: fileNameLocalPath, account: self.metadata.account, requestHandler: { _ in
                            }, taskHandler: { task in
                                self.database.setMetadataSession(metadata: self.metadata,
                                                                 sessionTaskIdentifier: task.taskIdentifier,
                                                                 status: self.global.metadataStatusDownloading)
                            }, progressHandler: { _ in
                            }, completionHandler: { account, etag, _, _, responseData, _, error in
                                NCActivityIndicator.shared.stop()
                                self.database.setMetadataSession(metadata: self.metadata,
                                                                 session: "",
                                                                 sessionTaskIdentifier: 0,
                                                                 sessionError: "",
                                                                 status: self.global.metadataStatusNormal,
                                                                 etag: etag)
                                if error == .success && account == self.metadata.account {
                                    var item = fileNameLocalPath

                                    if let allHeaderFields = responseData?.response?.allHeaderFields {
                                        if let disposition = allHeaderFields["Content-Disposition"] as? String {
                                            let components = disposition.components(separatedBy: "filename=")
                                            if let filename = components.last?.replacingOccurrences(of: "\"", with: "") {
                                                item = self.utilityFileSystem.directoryUserData + "/" + filename
                                                _ = self.utilityFileSystem.moveFile(atPath: fileNameLocalPath, toPath: item)
                                            }
                                        }
                                    }

                                    if type == "print" {
                                        let pic = UIPrintInteractionController.shared
                                        let printInfo = UIPrintInfo.printInfo()
                                        printInfo.outputType = UIPrintInfo.OutputType.general
                                        printInfo.orientation = UIPrintInfo.Orientation.portrait
                                        printInfo.jobName = "Document"
                                        pic.printInfo = printInfo
                                        pic.printingItem = URL(fileURLWithPath: item)
                                        pic.present(from: CGRect.zero, in: self.view, animated: true, completionHandler: { _, _, _ in })
                                    } else {
                                        self.documentController = UIDocumentInteractionController()
                                        self.documentController?.url = URL(fileURLWithPath: item)
                                        self.documentController?.presentOptionsMenu(from: CGRect.zero, in: self.view, animated: true)
                                    }
                                } else {

                                    NCContentPresenter().showError(error: error)
                                }
                            })
                        }
                    }
                } else if param["MessageName"] as? String == "fileRename" {
                    if let values = param["Values"] as? [AnyHashable: Any] {
                        guard let newName = values["NewName"] as? String else {
                            return
                        }
                        metadata.fileName = newName
                        metadata.fileNameView = newName
                    }
                } else if param["MessageName"] as? String == "hyperlink" {
                    if let values = param["Values"] as? [AnyHashable: Any] {
                        guard let urlString = values["Url"] as? String else {
                            return
                        }
                        if let url = URL(string: urlString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            if message.body as? String == "documentLoaded" {
                print("documentLoaded")
            }

            if message.body as? String == "paste" {
                // ?
            }
        }
    }

    // MARK: -

    @objc func grabFocus() {
        let functionJS = "OCA.RichDocuments.documentsMain.postGrabFocus()"
        webView.evaluateJavaScript(functionJS) { _, _ in }
    }

    // MARK: -

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session) {
        if let serverUrl, let metadata {
            let path = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: serverUrl, session: session)

            NextcloudKit.shared.createAssetRichdocuments(path: path, account: metadata.account) { _, url, _, error in
                if error == .success, let url {
                    let functionJS = "OCA.RichDocuments.documentsMain.postAsset('\(metadata.fileNameView)', '\(url)')"
                    self.webView.evaluateJavaScript(functionJS, completionHandler: { _, _ in })
                } else {
                    NCContentPresenter().showError(error: error)
                }
            }
        }
    }

    func select(_ metadata: tableMetadata!, serverUrl: String!) {
        let path = utilityFileSystem.getFileNamePath(metadata!.fileName, serverUrl: serverUrl!, session: session)

        NextcloudKit.shared.createAssetRichdocuments(path: path, account: metadata.account) { _, url, _, error in
            if error == .success, let url {
                let functionJS = "OCA.RichDocuments.documentsMain.postAsset('\(metadata.fileNameView)', '\(url)')"
                self.webView.evaluateJavaScript(functionJS, completionHandler: { _, _ in })
            } else {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    // MARK: -

    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        DispatchQueue.global().async {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
            }
        }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation")
    }

    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirectForProvisionalNavigation")
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NCActivityIndicator.shared.stop()
    }
}

extension NCViewerRichDocument: UINavigationControllerDelegate {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)

        if parent == nil {
            NCNetworking.shared.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: metadata.serverUrl)
            }
        }
    }
}

extension NCViewerRichDocument: NCTransferDelegate {
    func transferChange(status: String, metadata: tableMetadata, error: NKError) {
        DispatchQueue.main.async {
            switch status {
            /// FAVORITE
            case NCGlobal.shared.networkingStatusFavorite:
                if self.metadata.ocId == metadata.ocId {
                    self.metadata = metadata
                }
            default:
                break
            }
        }
    }
}
