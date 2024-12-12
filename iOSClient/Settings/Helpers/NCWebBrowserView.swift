//
//  NCWebBrowserView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 04/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Aditya Tyagi <adityagi02@yahoo.com>
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

import SwiftUI
@preconcurrency import WebKit

/// Returns a WebView preferably for Sheets in SwiftUI, using a UIViewRepresentable struct with WebKit library
///
/// - Parameters:
///   - isPresented: A Bool value which initiates the webView in the parentView
///   - urlBase: A URL value to which our view will open initially
///   - browserTitle: A String value to show as the title of the webView
struct NCBrowserWebView: View {
    var urlBase: URL
    var browserTitle: String
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(alignment: .center) {
                    Text(browserTitle)
                        .font(.title3)
                        .foregroundColor(Color(NCBrandColor.shared.textColor))
                        .padding(.leading, 8)
                }
                .padding()
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    ZStack {
                        Image(systemName: "xmark")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .font(Font.system(.body).weight(.light))
                            .frame(width: 14, height: 14)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                    }
                }
                .padding()
            }
            Divider()
            WebView(url: urlBase)
        }
        .navigationBarTitle(Text(""), displayMode: .inline) // Empty title to hide default navigation bar title
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        init(_ parent: WebView) {
            self.parent = parent
        }
        public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.useCredential, nil)
            }
        }
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
