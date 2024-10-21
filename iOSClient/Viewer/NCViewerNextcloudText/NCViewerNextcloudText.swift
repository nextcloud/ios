//
//  NCViewerNextcloudText.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/12/19.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

class NCViewerNextcloudText: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    var webView = WKWebView()
    var bottomConstraint: NSLayoutConstraint?
    var link: String = ""
    var editor: String = ""
    var metadata: tableMetadata = tableMetadata()
    var imageIcon: UIImage?
    let utility = NCUtility()

    // MARK: - View Life Cycle

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if !metadata.ocId.hasPrefix("TEMP") {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: NCImageCache.shared.getImageButtonMore(), style: .plain, target: self, action: #selector(self.openMenuMore))
        }
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.title = metadata.fileNameView

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let contentController = config.userContentController
        contentController.add(self, name: "DirectEditingMobileInterface")
        // FIXME: ONLYOFFICE Due to the WK Shared Workers issue the editors cannot be opened on the devices with iOS 16.1.
        if editor == NCGlobal.shared.editorOnlyoffice {
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

        if editor == NCGlobal.shared.editorOnlyoffice {
            webView.customUserAgent = utility.getCustomUserAgentOnlyOffice()
        } else if editor == NCGlobal.shared.editorText {
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

        NotificationCenter.default.addObserver(self, selector: #selector(favoriteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NCActivityIndicator.shared.start(backgroundView: view)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        webView.configuration.userContentController.removeScriptMessageHandler(forName: "DirectEditingMobileInterface")

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func viewUnload() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - NotificationCenter

    @objc func favoriteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              ocId == self.metadata.ocId,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else { return }

        self.metadata = metadata
    }

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

    @objc func openMenuMore() {
        if imageIcon == nil { imageIcon = NCUtility().loadImage(named: "doc.text", colors: [NCBrandColor.shared.iconImageColor]) }
        NCViewer().toggleMenu(controller: (self.tabBarController as? NCMainTabBarController), metadata: metadata, webView: true, imageIcon: imageIcon)
    }

    // MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "DirectEditingMobileInterface" {

            if message.body as? String == "close" {
                viewUnload()
            }

            if message.body as? String == "share" {
                NCActionCenter.shared.openShare(viewController: self, metadata: metadata, page: .sharing)
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

        if parent == nil {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterGetServerData, userInfo: ["serverUrl": self.metadata.serverUrl])
        }
    }
}
