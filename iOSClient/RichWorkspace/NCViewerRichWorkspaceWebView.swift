// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
@preconcurrency import WebKit

class NCViewerRichWorkspaceWebView: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {

    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var webViewBottomConstraint: NSLayoutConstraint!

    var metadata: tableMetadata?
    var url: String = ""

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        var request = URLRequest(url: URL(string: url)!)
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        let language = NSLocale.preferredLanguages[0] as String
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        webView.configuration.userContentController.add(self, name: "DirectEditingMobileInterface")
        webView.navigationDelegate = self
        webView.customUserAgent = userAgent
        webView.load(request)
    }

    deinit {
        print("dealloc")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "DirectEditingMobileInterface")
    }

    @objc func keyboardDidShow(notification: Notification) {
        let window = UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.first { $0.isKeyWindow }
        let safeAreaInsetsBottom = window?.safeAreaInsets.bottom ?? 0
        guard let info = notification.userInfo else { return }
        guard let frameInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardFrame = frameInfo.cgRectValue
        webViewBottomConstraint.constant = keyboardFrame.size.height - safeAreaInsetsBottom
    }

    @objc func keyboardWillHide(notification: Notification) {
        webViewBottomConstraint.constant = 0
    }

    // MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        if message.name == "DirectEditingMobileInterface" {

            if message.body as? String == "close" {

                self.presentationController?.delegate?.presentationControllerWillDismiss?(self.presentationController!)

                dismiss(animated: true) {
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView, userInfo: nil)
                }
            }

            if message.body as? String == "share" {
                if metadata != nil {
                    NCDownloadAction.shared.openShare(viewController: self, metadata: metadata!, page: .sharing)
                }
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
        print("didFinish")
    }
}
