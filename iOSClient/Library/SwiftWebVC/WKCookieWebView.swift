//
//  WKCookieWebView.swift
//


import Foundation
import WebKit

class WKCookieWebView : WKWebView {

    private let useRedirectCookieHandling: Bool

    init(frame: CGRect, configuration: WKWebViewConfiguration, useRedirectCookieHandling: Bool = false) {
        self.useRedirectCookieHandling = useRedirectCookieHandling
        super.init(frame: frame, configuration: configuration)
    }
    
    required init?(coder: NSCoder) {
        self.useRedirectCookieHandling = false
        super.init(coder: coder)
    }

    override func load(_ request: URLRequest) -> WKNavigation? {
        
        var request = request
        let language = NSLocale.preferredLanguages[0] as String
        
        request.setValue(CCUtility.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        guard useRedirectCookieHandling else {
            return super.load(request)
        }

        requestWithCookieHandling(request, success: { (newRequest , response, data) in
            DispatchQueue.main.async {
                self.syncCookiesInJS()
                if let data = data, let response = response {
                    let _ = self.webViewLoad(data: data, response: response)
                }
            }
        }, failure: {
            // let WKWebView handle the network error
            DispatchQueue.main.async {
                let _ = super.load(request)
            }
        })

        return nil
    }

    private func requestWithCookieHandling(_ request: URLRequest, success: @escaping (URLRequest, HTTPURLResponse?, Data?) -> Void, failure: @escaping () -> Void) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request) { (data, response, error) in
            if let _ = error {
                failure()
            } else {
                if let response = response as? HTTPURLResponse {
                    success(request, response, data)
                }
            }
        }
        task.resume()
    }

    private func webViewLoad(data: Data, response: URLResponse) -> WKNavigation! {
        guard let url = response.url else {
            return nil
        }

        let encode = response.textEncodingName ?? "utf8"
        let mine = response.mimeType ?? "text/html"

        return self.load(data, mimeType: mine, characterEncodingName: encode, baseURL: url)
    }
}

extension WKCookieWebView {
   
    // MARK: - JS Cookie handling
    private func syncCookiesInJS(for request: URLRequest? = nil) {
        if let url = request?.url,
            let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let script = jsCookiesString(for: cookies)
            let cookieScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            self.configuration.userContentController.addUserScript(cookieScript)

        } else if let cookies = HTTPCookieStorage.shared.cookies {
            let script = jsCookiesString(for: cookies)
            let cookieScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            self.configuration.userContentController.addUserScript(cookieScript)
        }
    }

    private func jsCookiesString(for cookies: [HTTPCookie]) -> String {
        var result = ""
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss zzz"

        for cookie in cookies {
            result += "document.cookie='\(cookie.name)=\(cookie.value); domain=\(cookie.domain); path=\(cookie.path); "
            if let date = cookie.expiresDate {
                result += "expires=\(dateFormatter.string(from: date)); "
            }
            if (cookie.isSecure) {
                result += "secure; "
            }
            result += "'; "
        }
        return result
    }
}

extension WKCookieWebView : URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request)
    }
}
