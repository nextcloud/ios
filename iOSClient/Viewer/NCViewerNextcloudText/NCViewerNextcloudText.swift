// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
@preconcurrency import WebKit

class NCViewerNextcloudText: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    var webView = WKWebView()
    var bottomConstraint: NSLayoutConstraint?
    var link: String = ""
    var editor: String = ""
    var metadata: tableMetadata = tableMetadata()
    var imageIcon: UIImage?
    let utility = NCUtility()
    var items: [UIBarButtonItem] = []

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
            let moreButton = UIBarButtonItem(
                image: NCImageCache.shared.getImageButtonMore(),
                primaryAction: nil,
                menu: UIMenu(title: "", children: [
                    UIDeferredMenuElement.uncached { [self] completion in
                        if let menu = NCViewerContextMenu.makeContextMenu(controller: self.tabBarController as? NCMainTabBarController, metadata: self.metadata, webView: true, sender: self) {
                            completion(menu.children)
                        }
                    }
                ]))

            items.append(moreButton)
        }

        navigationItem.rightBarButtonItems = items
        navigationItem.leftBarButtonItems = nil
        if editor == "nextcloud text" {
            navigationItem.hidesBackButton = true
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let contentController = config.userContentController
        contentController.add(self, name: "DirectEditingMobileInterface")
        // FIXME: ONLYOFFICE Due to the WK Shared Workers issue the editors cannot be opened on the devices with iOS 16.1.
        if editor == "onlyoffice" {
            let dropSharedWorkersScript = WKUserScript(source: "delete window.SharedWorker;", injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(dropSharedWorkersScript)
        }
        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = false
        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        webView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: 0).isActive = true
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        bottomConstraint = webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 70)
        bottomConstraint?.isActive = true

        if editor == "onlyoffice" {
            webView.customUserAgent = utility.getCustomUserAgentOnlyOffice()
        } else if editor == "nextcloud text" {
            webView.customUserAgent = utility.getCustomUserAgentNCText()
        } // else: use default

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

        webView.configuration.userContentController.removeScriptMessageHandler(forName: "DirectEditingMobileInterface")

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

    // MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "DirectEditingMobileInterface" {
            if message.body as? String == "close" {
                viewUnload()
            }

            if message.body as? String == "share" {
                NCCreate().createShare(viewController: self, metadata: metadata, page: .sharing)
            }

            if message.body as? String == "loading" {
                print("loading")
            }

            if message.body as? String == "loaded" {
                print("loaded")
            }

            if message.body as? String == "paste" {
                self.paste(self)
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

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url, UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
        return nil
    }
}

extension NCViewerNextcloudText: UINavigationControllerDelegate {
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

extension NCViewerNextcloudText: NCTransferDelegate {
    func transferReloadData(serverUrl: String?) { }

    func transferReloadDataSource(serverUrl: String?, requestData: Bool, status: Int?) { }

    func transferProgressDidUpdate(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) { }

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
