//
//  SwiftUIView.swift
//  Nextcloud
//
//  Created by Milen on 21.05.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//  Copyright © 2024 STRATO GmbH
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

import NextcloudKit
import SwiftUI
import SafariServices

struct NCLoginPoll: View {
    let loginFlowV2Token: String
    let loginFlowV2Endpoint: String
    let loginFlowV2Login: String
    
    var cancelButtonDisabled = false
    
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    @ObservedObject private var loginManager = LoginManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let welcomeLabelWidthRatio = isIPad ? 0.6 : 0.78
            let descriptionFont = Font.system(size: isIPad ? 36.0 : 16.0)
            
            VStack {
                Image(.logo)
                    .resizable()
                    .aspectRatio(159/22, contentMode: .fit)
                    .frame(width: size.width * 0.45)
                    .padding(.top, size.height * 0.12)
                Text(NSLocalizedString("_poll_desc_", comment: ""))
                    .font(descriptionFont)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .frame(width: size.width * welcomeLabelWidthRatio)
                    .padding(.top, size.height * 0.1)
                
                Spacer()
                CircleItemSpinner()
                    .tint(.white)
                Spacer()
                
                HStack(spacing: 15) {
                    Button(NSLocalizedString("_cancel_", comment: "")) {
                        dismiss()
                    }
                    .disabled(loginManager.isLoading || cancelButtonDisabled)
                    .buttonStyle(ButtonStyleSecondary(maxWidth: .infinity))
                    
                    Button(NSLocalizedString("_retry_", comment: "")) {
                        loginManager.openLoginInBrowser()
                    }
                    .buttonStyle(ButtonStylePrimary(maxWidth: .infinity))
                    
				}
                .frame(width: size.width * (isIPad ? 0.60 : 0.80))
				.padding(.bottom, size.height * 0.15)
                .environment(\.colorScheme, .dark)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Image(.gradientBackground)
                    .resizable()
                    .ignoresSafeArea()
            }
        }
        .onChange(of: loginManager.pollFinished) { value in
                if value {
                    let window = UIApplication.shared.firstWindow
                    
                    if window?.rootViewController is NCMainTabBarController {
                        window?.rootViewController?.dismiss(animated: true, completion: nil)
                    } else {
                        if let mainTabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                            mainTabBarController.modalPresentationStyle = .fullScreen
                            mainTabBarController.view.alpha = 0
                            window?.rootViewController = mainTabBarController
                            window?.makeKeyAndVisible()
							
							if let scene = window?.windowScene {
								SceneManager.shared.register(scene: scene, withRootViewController: mainTabBarController)
							}
							
                            UIView.animate(withDuration: 0.5) {
                                mainTabBarController.view.alpha = 1
                            }
                        }
                    }
                }
        }
        .onAppear {
			if #available(iOS 16.0, *) {
				SFSafariViewController.DataStore.default.clearWebsiteData()
			}
			
            loginManager.configure(loginFlowV2Token: loginFlowV2Token, loginFlowV2Endpoint: loginFlowV2Endpoint, loginFlowV2Login: loginFlowV2Login)

            if !isRunningForPreviews {
                loginManager.openLoginInBrowser()
            }
        }
        .interactiveDismissDisabled()
        .fullScreenCover(item: $loginManager.browserURL, content: { url in
            SafariView(url: url) {
                loginManager.browserURL = nil
                loginManager.poll()
            }
            .ignoresSafeArea()
        })
    }
}


#Preview {
	NCLoginPoll(loginFlowV2Token: "", loginFlowV2Endpoint: "", loginFlowV2Login: "")
}

private class LoginManager: ObservableObject {
    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    var loginFlowV2Token = ""
    var loginFlowV2Endpoint = ""
    var loginFlowV2Login = ""

    @Published var pollFinished = false
    @Published var isLoading = false
    @Published var browserURL: URL?

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        poll()
    }

    func configure(loginFlowV2Token: String, loginFlowV2Endpoint: String, loginFlowV2Login: String) {
        self.loginFlowV2Token = loginFlowV2Token
        self.loginFlowV2Endpoint = loginFlowV2Endpoint
        self.loginFlowV2Login = loginFlowV2Login
    }

    func poll() {
        let loginOptions = NKRequestOptions(customUserAgent: userAgent)
        NextcloudKit.shared.getLoginFlowV2Poll(token: self.loginFlowV2Token, 
                                               endpoint: self.loginFlowV2Endpoint,
                                               options: loginOptions) { server, loginName, appPassword, _, error in
            if error == .success, let urlBase = server, let user = loginName, let appPassword {
                self.isLoading = true
                self.appDelegate.createAccount(urlBase: urlBase, user: user, password: appPassword) { error in
                    if error == .success {
                        self.pollFinished = true
                    }
                }
            }
        }
    }

    func openLoginInBrowser() {
        browserURL = URL(string: loginFlowV2Login)
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let onFinished: () -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariVC = SFSafariViewController(url: url)
        safariVC.delegate = context.coordinator
        return safariVC
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: SafariView

        init(_ parent: SafariView) {
            self.parent = parent
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            controller.dismiss(animated: true) { [weak self] in
                self?.parent.onFinished()
            }
        }
    }
}

extension URL: Identifiable {
    public var id: String {
        return self.absoluteString
    }
}
