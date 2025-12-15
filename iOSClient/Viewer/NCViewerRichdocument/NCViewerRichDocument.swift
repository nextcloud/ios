// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: NCImageCache.shared.getImageButtonMore(),
                primaryAction: nil,
                menu: UIMenu(title: "", children: [
                    UIDeferredMenuElement.uncached { [self] completion in
                        if let menu = NCViewerContextMenu.makeContextMenu(controller: self.tabBarController as? NCMainTabBarController, metadata: self.metadata, webView: true, sender: self) {
                            completion(menu.children)
                        }
                    }
                ]))
        }
        navigationItem.hidesBackButton = true

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let contentController = config.userContentController
        contentController.add(self, name: "RichDocumentsMobileInterface")

        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView.navigationDelegate = self

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

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

        if #available(iOS 18.0, *) {
            tabBarController?.setTabBarHidden(true, animated: true)
        } else {
            tabBarController?.tabBar.isHidden = true
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.grabFocus), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRichdocumentGrabFocus), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task {
            await NCNetworking.shared.transferDispatcher.addDelegate(self)
        }

        NCActivityIndicator.shared.start(backgroundView: view)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if #available(iOS 18.0, *) {
            tabBarController?.setTabBarHidden(false, animated: true)
        } else {
            tabBarController?.tabBar.isHidden = false
        }

        Task {
            await NCNetworking.shared.transferDispatcher.removeDelegate(self)
        }

        if let navigationController = self.navigationController {
            if !navigationController.viewControllers.contains(self) {
                let functionJS = "OCA.RichDocuments.documentsMain.onClose()"
                webView.evaluateJavaScript(functionJS) { _, _ in
                    print("close")
                }
            }
        }

        webView.configuration.userContentController.removeScriptMessageHandler(forName: "RichDocumentsMobileInterface")

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRichdocumentGrabFocus), object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
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

    // MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "RichDocumentsMobileInterface" {
            if message.body as? String == "close" {
                navigationController?.popViewController(animated: true)
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
                NCCreate().createShare(viewController: self, metadata: metadata, page: .sharing)
            }

            if let param = message.body as? [AnyHashable: Any] {
                if param["MessageName"] as? String == "downloadAs" {
                    if let values = param["Values"] as? [AnyHashable: Any] {
                        guard let type = values["Type"] as? String else { return }
                        guard let urlString = values["URL"] as? String else { return }
                        guard let url = URL(string: urlString) else { return }
                        var fileName = (metadata.fileName as NSString).deletingPathExtension
                        let fileNameLocalPath = utilityFileSystem.createServerUrl(serverUrl: utilityFileSystem.directoryUserData, fileName: fileName)

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
                                Task {
                                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.metadata.account,
                                                                                                                path: url.absoluteString,
                                                                                                                name: "download")
                                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)

                                    let ocId = self.metadata.ocId
                                    await self.database.setMetadataSessionAsync(ocId: ocId,
                                                                                sessionTaskIdentifier: task.taskIdentifier,
                                                                                status: self.global.metadataStatusDownloading)
                                }
                            }, progressHandler: { _ in
                            }, completionHandler: { account, etag, _, _, headers, _, error in
                                NCActivityIndicator.shared.stop()
                                Task {
                                    let ocId = self.metadata.ocId
                                    await self.database.setMetadataSessionAsync(ocId: ocId,
                                                                                session: "",
                                                                                sessionTaskIdentifier: 0,
                                                                                sessionError: "",
                                                                                status: self.global.metadataStatusNormal,
                                                                                etag: etag)
                                }
                                if error == .success && account == self.metadata.account {
                                    var item = fileNameLocalPath

                                    if let headers {
                                        if let disposition = headers["Content-Disposition"] as? String,
                                           let filenameContentDisposition = self.filenameFromContentDisposition(disposition) {
                                            fileName = filenameContentDisposition
                                            item = self.utilityFileSystem.createServerUrl(serverUrl: self.utilityFileSystem.directoryUserData, fileName: fileName)
                                            _ = self.utilityFileSystem.moveFile(atPath: fileNameLocalPath, toPath: item)
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

            NextcloudKit.shared.createAssetRichdocuments(path: path, account: metadata.account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                                path: path,
                                                                                                name: "createAssetRichdocuments")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            } completion: { _, url, _, error in
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

        NextcloudKit.shared.createAssetRichdocuments(path: path, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: path,
                                                                                            name: "createAssetRichdocuments")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, url, _, error in
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

    // MARK: - Hekper

    func filenameFromContentDisposition(_ disposition: String) -> String? {
        if let range = disposition.range(of: "filename=") {
            var value = String(disposition[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            // Cut at next ';' if present
            if let semi = value.firstIndex(of: ";") {
                value = String(value[..<semi])
            }
            // Remove optional quotes
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return value.isEmpty ? nil : value
        }
        return nil
    }
}

extension NCViewerRichDocument: UINavigationControllerDelegate {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)

        Task {
            if parent == nil {
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: metadata.serverUrl, requestData: false, status: nil)
                }
            }
        }
    }
}

extension NCViewerRichDocument: NCTransferDelegate {
    func transferChange(status: String,
                        account: String,
                        fileName: String,
                        serverUrl: String,
                        selector: String?,
                        ocId: String,
                        destination: String?,
                        error: NKError) {
        Task {@MainActor in
            if status == NCGlobal.shared.networkingStatusFavorite,
               self.metadata.ocId == ocId,
               let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId) {
                self.metadata = metadata
            }
        }
    }
}
