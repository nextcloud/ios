//
//  SceneDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/04/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

class SceneManager {
    static let shared = SceneManager()
    private var sceneRootViewController: [NCMainTabBar: UIScene] = [:]
    private var activeSceneRootViewController: NCMainTabBar?
    //
    class Files {
        let files: NCFiles
        let serverUrl: String
        let tabBarController: UITabBarController
        var active: Bool = false

        init(files: NCFiles, serverUrl: String, tabBarController: UITabBarController) {
            self.files = files
            self.serverUrl = serverUrl
            self.tabBarController = tabBarController
        }
    }
    private var files: [Files] = []

    private init() {}

    /*
    func register(scene: UIScene, withRootViewController rootViewController: NCMainTabBar) {
        sceneRootViewController[rootViewController] = scene
    }

    func setActiveSceneRootViewController(_ rootViewController: NCMainTabBar) {
        assert(sceneRootViewController[rootViewController] != nil, "Scene must be registered before it can be set as active")
        activeSceneRootViewController = rootViewController
    }

    func activeScene() -> UIScene? {
        guard let rootViewController = activeSceneRootViewController else { return nil }
        return sceneRootViewController[rootViewController]
    }
    */

    //

    func active(files: NCFiles, withServerUrl serverUrl: String, withTabBarController tabBarController: UITabBarController?) {
        guard let tabBarController else { return }

        if self.files.filter({ $0.serverUrl == serverUrl && $0.tabBarController == tabBarController }).first == nil {
            self.files.append(Files(files: files, serverUrl: serverUrl, tabBarController: tabBarController))
        }
        let results = self.files.filter { $0.tabBarController == tabBarController }
        for result in results {
            if result.serverUrl == serverUrl {
                result.active = true
            } else {
                result.active = false
            }
        }
    }

    func deactivate(serverUrl: String, withTabBarController tabBarController: UITabBarController?) {
        guard let tabBarController else { return }

        if let result = self.files.filter({ $0.serverUrl == serverUrl && $0.tabBarController == tabBarController }).first {
            result.active = false
        }
    }

    func getActiveFiles(serverUrl: String, withTabBarController tabBarController: UITabBarController?) -> NCFiles? {
        guard let tabBarController else { return nil }
        return (self.files.filter { $0.serverUrl == serverUrl && $0.tabBarController == tabBarController && $0.active == true }.first)?.files
    }
}
