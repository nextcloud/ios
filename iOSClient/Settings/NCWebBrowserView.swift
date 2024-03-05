//
//  NCWebBrowserView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 04/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI
import WebKit


/// Returns a WebView preferably for Sheets in SwiftUI, using a UIViewRepresentable struct with WebKit library
///
/// - Parameters:
///   - isPresented: A Bool value which initiates the webView in the parentView
///   - urlBase: A URL value to which our view will open initially
///   - browserTitle: A String value to show as the title of the webView
struct NCBrowserWebView: View {

    @Binding var isPresented: Bool
    var urlBase: URL
    var browserTitle: String
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        VStack(spacing: 0) {
            HStack() {
                
                HStack(alignment: .center) {
                    Text(browserTitle)
                        .font(.title3)
                        .foregroundColor(Color(UIColor.label))
                        .padding(.leading, 8)
                }
                .padding()
                
                Spacer()
                
                Button(action: {
                    self.isPresented = false
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.secondarySystemBackground))
                            .frame(width: 25, height: 25)
                        
                        Image(systemName: "xmark")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 14, height: 14)
                            .foregroundColor(.gray)
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
