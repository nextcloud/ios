// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
@preconcurrency import WebKit

@objc protocol NCBrowserWebDelegate: AnyObject {
    @objc optional func browserWebDismiss()
}

class NCBrowserWeb: UIViewController {

    var urlBase = ""
    var isHiddenButtonExit = false
    var titleBrowser: String?
    weak var delegate: NCBrowserWebDelegate?

    @IBOutlet weak var buttonExit: UIButton!

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let webView = WKWebView(frame: CGRect.zero)
        webView.navigationDelegate = self
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        webView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        webView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

        if isHiddenButtonExit {
            buttonExit.isHidden = true
        } else {
            self.view.bringSubviewToFront(buttonExit)
            let image = NCUtility().loadImage(named: "xmark", colors: [.systemBlue])
            buttonExit.setImage(image, for: .normal)
        }

        if let url = URL(string: urlBase) {
            loadWebPage(webView: webView, url: url)
        } else {
            let url = URL(fileURLWithPath: urlBase)
            loadWebPage(webView: webView, url: url)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let titleBrowser = titleBrowser {
            navigationItem.title = titleBrowser
        }
    }

    deinit {

    }

    // MARK: - Action

    @IBAction func touchUpInsideButtonExit(_ sender: UIButton) {
        self.dismiss(animated: true) {
            self.delegate?.browserWebDismiss?()
        }
    }

    func loadWebPage(webView: WKWebView, url: URL) {

        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)

        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        webView.customUserAgent = userAgent
        webView.load(request)
    }
}

extension NCBrowserWeb: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        DispatchQueue.global().async {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
            }
        }
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        DispatchQueue.global().async {
            decisionHandler(.allow)
        }
    }
}
