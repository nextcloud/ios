//
//  NCBrowserWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 22/08/2019.
//  Copyright (c) 2019 Marino Faggiana. All rights reserved.
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
import WebKit

@objc protocol NCBrowserWebDelegate: AnyObject {
    @objc optional func browserWebDismiss()
}

class NCBrowserWeb: UIViewController {

    var webView: WKWebView?

    @objc var urlBase = ""
    @objc var isHiddenButtonExit = false
    @objc var titleBrowser: String?
    @objc weak var delegate: NCBrowserWebDelegate?

    @IBOutlet weak var buttonExit: UIButton!

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        webView = WKWebView(frame: CGRect.zero)
        webView!.navigationDelegate = self
        view.addSubview(webView!)
        webView!.translatesAutoresizingMaskIntoConstraints = false
        webView!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        webView!.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        webView!.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        webView!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

        // button exit
        if isHiddenButtonExit {
            buttonExit.isHidden = true
        } else {
            self.view.bringSubviewToFront(buttonExit)
            let image = NCUtility.shared.loadImage(named: "xmark", color: .systemBlue)
            buttonExit.setImage(image, for: .normal)
        }

        if let url = URL(string: urlBase) {
            loadWebPage(webView: webView!, url: url)
        } else {
            let url = URL(fileURLWithPath: urlBase)
            loadWebPage(webView: webView!, url: url)
        }

        // navigationItem.rightBarButtonItem = UIBarButtonItem.init(image: UIImage(named: "more")!.image(color: NCBrandColor.shared.label, size: 25), style: .plain, target: self, action: #selector(self.openMenuMore))
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

    //

    func loadWebPage(webView: WKWebView, url: URL) {

        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)

        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")
        webView.customUserAgent = CCUtility.getUserAgent()

        webView.load(request)
    }
}

extension NCBrowserWeb: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
        }
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation")
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinishProvisionalNavigation")
    }

    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirectForProvisionalNavigation")
    }
}
