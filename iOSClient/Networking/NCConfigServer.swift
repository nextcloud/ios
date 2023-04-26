//
//  NCConfigServer.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/12/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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

import Foundation
import Swifter
import NextcloudKit

// Source:
// https://stackoverflow.com/questions/2338035/installing-a-configuration-profile-on-iphone-programmatically

@objc class NCConfigServer: NSObject, UIActionSheetDelegate, URLSessionDelegate {

    // Start service
    @objc func startService(url: URL) {

        let defaultSessionConfiguration = URLSessionConfiguration.default
        let defaultSession = URLSession(configuration: defaultSessionConfiguration, delegate: self, delegateQueue: .main)

        var urlRequest = URLRequest(url: url)
        urlRequest.headers = NextcloudKit.shared.nkCommonInstance.getStandardHeaders()

        let dataTask = defaultSession.dataTask(with: urlRequest) { (data, response, error) in
            if let error = error {
                NCContentPresenter.shared.showInfo(error: NKError(error: error))
            } else if let data = data {
                self.start(data: data)
            }
        }
        dataTask.resume()
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        NCNetworking.shared.checkTrustedChallenge(session, didReceive: challenge, completionHandler: completionHandler)
    }

    private enum ConfigState: Int {
        case Stopped, Ready, InstalledConfig, BackToApp
    }

    internal let listeningPort: in_port_t = 8080
    internal var configName: String = "Profile install"
    private var localServer: HttpServer?
    private var returnURL: String = ""
    private var configData: Data?

    private var serverState: ConfigState = .Stopped
    private var registeredForNotifications = false
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    deinit {
        unregisterFromNotifications()
    }

    // MARK: - Control functions

    internal func start(data: Data) {
        self.configData = data
        self.localServer = HttpServer()
        self.setupHandlers()

        let page = self.baseURL(pathComponent: "install/")
        let url = URL(string: page)!
        if UIApplication.shared.canOpenURL(url as URL) {
            do {
                try localServer?.start(listeningPort, forceIPv4: false, priority: .default)
                serverState = .Ready
                registerForNotifications()
                UIApplication.shared.open(url)
            } catch {
                NCContentPresenter.shared.showInfo(error: NKError(error: error))
                self.stop()
            }
        }
    }

    internal func stop() {
        if serverState != .Stopped {
            serverState = .Stopped
            unregisterFromNotifications()
        }
    }

    // MARK: - Private functions

    private func setupHandlers() {
        localServer?["/install"] = { request in
            switch self.serverState {
            case .Stopped:
                return .notFound()
            case .Ready:
                self.serverState = .InstalledConfig
                return HttpResponse.raw(200, "OK", ["Content-Type": "application/x-apple-aspen-config"], { writer in
                    do {
                        if let configData = self.configData {
                            try writer.write(configData)
                        }
                    } catch {
                        print("Failed to write response data")
                    }
                })
            case .InstalledConfig:
                return .movedPermanently(self.returnURL)
            case .BackToApp:
                let page = self.basePage(pathComponent: nil)
                return .ok(.html(page))
            }
        }
    }

    private func baseURL(pathComponent: String?) -> String {
        var page = "http://localhost:\(listeningPort)"
        if let component = pathComponent {
            page += "/\(component)"
        }
        return page
    }

    private func basePage(pathComponent: String?) -> String {
        var page = "<!doctype html><html>" + "<head><meta charset='utf-8'><title>\(self.configName)</title></head>"
        if let component = pathComponent {
            let script = "function load() { window.location.href='\(self.baseURL(pathComponent: component))'; } window.setInterval(load, 800);"
            page += "<script>\(script)</script>"
        }
        page += "<body></body></html>"
        return page
    }

    private func returnedToApp() {
        if serverState != .Stopped {
            serverState = .BackToApp
            localServer?.stop()
        }
    }

    private func registerForNotifications() {
        if !registeredForNotifications {
            let notificationCenter = NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            registeredForNotifications = true
        }
    }

    private func unregisterFromNotifications() {
        if registeredForNotifications {
            let notificationCenter = NotificationCenter.default
            notificationCenter.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
            registeredForNotifications = false
        }
    }

    @objc internal func didEnterBackground(notification: NSNotification) {
        if serverState != .Stopped {
            startBackgroundTask()
        }
    }

    @objc internal func willEnterForeground(notification: NSNotification) {
        if backgroundTask != UIBackgroundTaskIdentifier.invalid {
            stopBackgroundTask()
            returnedToApp()
        }
    }

    private func startBackgroundTask() {
        let application = UIApplication.shared
        backgroundTask = application.beginBackgroundTask(expirationHandler: {
            DispatchQueue.main.async {
                self.stopBackgroundTask()
            }
        })
    }

    private func stopBackgroundTask() {
        if backgroundTask != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            backgroundTask = UIBackgroundTaskIdentifier.invalid
        }
    }
}
