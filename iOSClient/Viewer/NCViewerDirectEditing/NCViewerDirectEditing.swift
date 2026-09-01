// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
@preconcurrency import WebKit

final class NCViewerDirectEditing: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    private let directEditingMobileInterface = "DirectEditingMobileInterface"
    private let richDocumentsMobileInterface = "RichDocumentsMobileInterface"

    var link: String
    var editor: String
    var userAgent: String
    private(set) var metadata: tableMetadata
    var imageIcon: UIImage?

    var webView = WKWebView()
    var bottomConstraint: NSLayoutConstraint?
    var documentController: UIDocumentInteractionController?
    let utility = NCUtility()
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    var items: [UIBarButtonItem] = []

    @MainActor
    var session: NCSession.Session {
        NCSession.shared.getSession(account: metadata.account)
    }

    @MainActor
    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    var sceneIdentifier: String {
        (self.tabBarController as? NCMainTabBarController)?.sceneIdentifier ?? ""
    }

    // MARK: - View Life Cycle

    init?(coder: NSCoder, link: String, editor: String, userAgent: String, metadata: tableMetadata, imageIcon: UIImage?) {
        guard !link.isEmpty,
              !editor.isEmpty,
              !userAgent.isEmpty else {
            return nil
        }

        self.link = link
        self.editor = editor
        self.userAgent = userAgent
        self.metadata = metadata
        self.imageIcon = imageIcon

        super.init(coder: coder)
    }

    @available(*, unavailable, message: "Use the dependency initializer")
    required init?(coder: NSCoder) {
        fatalError(
            "Use init(coder:link:editor:userAgent:metadata:imageIcon:)"
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let moreButton = UIBarButtonItem(
            image: NCImageCache.shared.getImageButtonMore(),
            primaryAction: nil,
            menu: UIMenu(title: "", children: [
                UIDeferredMenuElement.uncached { [self] completion in
                    if let menu = NCContextMenuViewer(metadata: self.metadata,
                                                      controller: self.tabBarController as? NCMainTabBarController,
                                                      viewController: self.tabBarController,
                                                      webView: true,
                                                      sender: self).viewMenu() {
                        completion(menu.children)
                    }
                }
            ]))
        items.append(moreButton)

        let group = UIBarButtonItemGroup(
            barButtonItems: items,
            representativeItem: nil
        )
        navigationItem.trailingItemGroups = [group]
        navigationItem.leftBarButtonItems = nil

        // Prevent back navigation gesture of iOS >= 26 as that can cause unintended swipe backs
        if #available(iOS 26.0, *) {
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = false
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let contentController = config.userContentController
        contentController.add(self, name: directEditingMobileInterface)
        if editor == global.editorCollabora {
            contentController.add(self, name: richDocumentsMobileInterface)
        }
        if editor == global.editorEuroOffice {
            let dropSharedWorkersScript = WKUserScript(source: "delete window.SharedWorker;", injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(dropSharedWorkersScript)
        }
        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.customUserAgent = userAgent
        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        webView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: 0).isActive = true
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        bottomConstraint = webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        bottomConstraint?.isActive = true

        if let url = URL(string: link) {
            var request = URLRequest(url: url)
            request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
            let language = NSLocale.preferredLanguages[0] as String
            request.addValue(language, forHTTPHeaderField: "Accept-Language")

            webView.load(request)
        }
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

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        if editor == global.editorCollabora {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(grabRichDocumentsFocus),
                name: NSNotification.Name(rawValue: global.notificationCenterRichdocumentGrabFocus),
                object: nil
            )
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task {
            await NCNetworking.shared.transferDispatcher.addDelegate(self)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let isLeavingViewer = isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true
        if isLeavingViewer {
            if #available(iOS 26.0, *) {
                navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = true
            }

            if editor == global.editorCollabora {
                webView.evaluateJavaScript("OCA.RichDocuments.documentsMain.onClose()")
            }

            webView.configuration.userContentController.removeScriptMessageHandler(forName: directEditingMobileInterface)
            if editor == global.editorCollabora {
                webView.configuration.userContentController.removeScriptMessageHandler(forName: richDocumentsMobileInterface)
            }
        }

        if #available(iOS 18.0, *) {
            tabBarController?.setTabBarHidden(false, animated: true)
        } else {
            tabBarController?.tabBar.isHidden = false
        }

        Task {
            await NCNetworking.shared.transferDispatcher.removeDelegate(self)
        }

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name(rawValue: global.notificationCenterRichdocumentGrabFocus),
            object: nil
        )
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

    @objc private func grabRichDocumentsFocus() {
        guard editor == global.editorCollabora else {
            return
        }

        webView.evaluateJavaScript("OCA.RichDocuments.documentsMain.postGrabFocus()")
    }

    // MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let isDirectEditingMessage = message.name == directEditingMobileInterface
        let isRichDocumentsMessage = editor == global.editorCollabora && message.name == richDocumentsMobileInterface

        guard isDirectEditingMessage || isRichDocumentsMessage,
              let mobileMessage = mobileMessage(from: message.body) else {
            return
        }

        switch mobileMessage.command {
        case "close":
            viewUnload()

        case "share":
            NCCreate().createShare(
                controller: controller,
                presentViewController: controller,
                metadata: metadata,
                page: .sharing
            )

        case "reload":
            webView.reload()

        case "loading":
            print("loading")

        case "loaded", "documentLoaded":
            print(mobileMessage.command)

        case "paste":
            paste(self)

        case "insertGraphic":
            presentImageSelector()

        case "downloadAs":
            guard let values = mobileMessage.values else { return }
            downloadRichDocument(values: values)

        case "fileRename":
            guard let values = mobileMessage.values,
                  let newName = values["NewName"] as? String else {
                return
            }
            metadata.fileName = newName
            metadata.fileNameView = newName

        case "hyperlink":
            guard let values = mobileMessage.values,
                  let urlString = values["Url"] as? String,
                  let url = URL(string: urlString) else {
                return
            }
            UIApplication.shared.open(url)

        default:
            break
        }
    }

    private func mobileMessage(from body: Any) -> (command: String, values: [AnyHashable: Any]?)? {
        if let command = body as? String {
            return (command, nil)
        }

        guard let parameters = body as? [AnyHashable: Any],
              let command = parameters["MessageName"] as? String else {
            return nil
        }

        return (command, parameters["Values"] as? [AnyHashable: Any])
    }

    private func presentImageSelector() {
        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        guard let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController,
              let viewController = navigationController.topViewController as? NCSelect else {
            return
        }

        viewController.delegate = self
        viewController.typeOfCommandView = .select
        viewController.enableSelectFile = true
        viewController.includeImages = true
        viewController.type = ""
        viewController.session = session
        viewController.controller = controller

        present(navigationController, animated: true)
    }

    private func downloadRichDocument(values: [AnyHashable: Any]) {
        guard let type = values["Type"] as? String,
              let urlString = values["URL"] as? String,
              let url = URL(string: urlString) else {
            return
        }

        var fileName = (metadata.fileName as NSString).deletingPathExtension
        let fileNameLocalPath = utilityFileSystem.createServerUrl(
            serverUrl: utilityFileSystem.directoryUserData,
            fileName: fileName
        )

        if type == "slideshow" {
            guard let browserWebViewController = UIStoryboard(name: "NCBrowserWeb", bundle: nil).instantiateInitialViewController() as? NCBrowserWeb else {
                return
            }

            browserWebViewController.urlBase = urlString
            browserWebViewController.isHiddenButtonExit = false
            present(browserWebViewController, animated: true)
            return
        }

        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.download(
            serverUrlFileName: url,
            fileNameLocalPath: fileNameLocalPath,
            account: metadata.account,
            requestHandler: { _ in },
            taskHandler: { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: self.metadata.account,
                        path: url.absoluteString,
                        name: "download"
                    )
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)

                    await self.database.setMetadataSessionAsync(
                        ocId: self.metadata.ocId,
                        sessionTaskIdentifier: task.taskIdentifier,
                        status: self.global.metadataStatusDownloading
                    )
                }
            },
            progressHandler: { _ in },
            completionHandler: { account, response, error in
                NCActivityIndicator.shared.stop()

                Task {
                    let nkCommon = NextcloudKit.shared.nkCommonInstance
                    let allHeaderFields = response?.response?.allHeaderFields
                    let etag = nkCommon.normalizedETag(nkCommon.findHeader("oc-etag", allHeaderFields: allHeaderFields))

                    await self.database.setMetadataSessionAsync(
                        ocId: self.metadata.ocId,
                        session: "",
                        sessionTaskIdentifier: 0,
                        sessionError: "",
                        status: self.global.metadataStatusNormal,
                        etag: etag
                    )
                }

                guard error == .success, account == self.metadata.account else {
                    Task {
                        let windowScene = SceneManager.shared.getWindow(sceneIdentifier: self.sceneIdentifier)?.windowScene
                        await showErrorBanner(windowScene: windowScene, text: error.errorDescription, errorCode: error.errorCode)
                    }
                    return
                }

                var item = fileNameLocalPath
                if let disposition = NextcloudKit.shared.nkCommonInstance.findHeader(
                    "Content-Disposition",
                    allHeaderFields: response?.response?.allHeaderFields
                ), let filenameContentDisposition = self.filenameFromContentDisposition(disposition) {
                    fileName = filenameContentDisposition
                    item = self.utilityFileSystem.createServerUrl(
                        serverUrl: self.utilityFileSystem.directoryUserData,
                        fileName: fileName
                    )
                    _ = self.utilityFileSystem.moveFile(atPath: fileNameLocalPath, toPath: item)
                }

                if type == "print" {
                    let printController = UIPrintInteractionController.shared
                    let printInfo = UIPrintInfo.printInfo()
                    printInfo.outputType = .general
                    printInfo.orientation = .portrait
                    printInfo.jobName = "Document"
                    printController.printInfo = printInfo
                    printController.printingItem = URL(fileURLWithPath: item)
                    printController.present(from: .zero, in: self.view, animated: true)
                } else {
                    self.documentController = UIDocumentInteractionController()
                    self.documentController?.url = URL(fileURLWithPath: item)
                    self.documentController?.presentOptionsMenu(from: .zero, in: self.view, animated: true)
                }
            }
        )
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
        NCActivityIndicator.shared.start(backgroundView: view)
    }

    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirectForProvisionalNavigation")
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NCActivityIndicator.shared.stop()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        NCActivityIndicator.shared.stop()
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        NCActivityIndicator.shared.stop()
    }

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url, UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
        return nil
    }

    private func filenameFromContentDisposition(_ disposition: String) -> String? {
        guard let range = disposition.range(of: "filename=") else {
            return nil
        }

        var value = String(disposition[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        if let semicolonIndex = value.firstIndex(of: ";") {
            value = String(value[..<semicolonIndex])
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        return value.isEmpty ? nil : value
    }

    private func postRichDocumentsAsset(fileName: String, url: String) {
        guard let fileNameData = try? JSONEncoder().encode(fileName),
              let urlData = try? JSONEncoder().encode(url),
              let fileNameLiteral = String(data: fileNameData, encoding: .utf8),
              let urlLiteral = String(data: urlData, encoding: .utf8) else {
            return
        }

        let function = "OCA.RichDocuments.documentsMain.postAsset(\(fileNameLiteral), \(urlLiteral))"
        webView.evaluateJavaScript(function)
    }
}

extension NCViewerDirectEditing: NCSelectDelegate {
    func dismissSelect(serverUrl: String?,
                       metadata: tableMetadata?,
                       type: String,
                       items: [Any],
                       overwrite: Bool,
                       copy: Bool,
                       move: Bool,
                       session: NCSession.Session,
                       controller: NCMainTabBarController?) {
        guard editor == global.editorCollabora,
              let serverUrl,
              let metadata else {
            return
        }

        let path = utilityFileSystem.getRelativeFilePath(metadata.fileName, serverUrl: serverUrl, session: session)
        NextcloudKit.shared.createRichdocumentsAssetURL(filePath: path, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: metadata.account,
                    path: path,
                    name: "createRichdocumentsAssetURL"
                )
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, url, _, error in
            if error == .success, let url {
                self.postRichDocumentsAsset(fileName: metadata.fileNameView, url: url)
            } else {
                Task {
                    let windowScene = SceneManager.shared.getWindow(sceneIdentifier: self.sceneIdentifier)?.windowScene
                    await showErrorBanner(windowScene: windowScene, text: error.errorDescription, errorCode: error.errorCode)
                }
            }
        }
    }
}

extension NCViewerDirectEditing: UINavigationControllerDelegate {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)

        Task {
            if parent == nil {
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadDataSource(serverUrl: self.metadata.serverUrl, requestData: true, status: nil)
                }
            }
        }
    }
}

extension NCViewerDirectEditing: NCTransferDelegate {
    func transferReloadData(serverUrl: String?) { }

    func transferReloadDataSource(serverUrl: String?, requestData: Bool, status: Int?) { }

    func transferProgressDidUpdate(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) { }

    func transferChange(networkingStatus: String,
                        account: String,
                        fileName: String,
                        serverUrl: String,
                        selector: String?,
                        ocId: String,
                        destination: String?,
                        error: NKError) {
        Task {@MainActor in
            if networkingStatus == NCGlobal.shared.networkingStatusFavorite,
               self.metadata.ocId == ocId,
               let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId) {
                self.metadata = metadata
            }
        }
    }
}
