//
//  NCCollectionViewCommonSelectionTabBar.swift
//  Nextcloud
//
//  Created by Milen on 01.02.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//  Copyright © 2024 STRATO AG
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
import SwiftUI

class HiDriveCollectionViewCommonSelectToolbar: ObservableObject {
    enum TabButton {
        case share
        case moveOrCopy
        case delete
        case download
        case lockOrUnlock
        case restore
    }
    
    private var hostingController: UIViewController?
    weak var controller: NCMainTabBarController?
    
    open weak var delegate: HiDriveCollectionViewCommonSelectToolbarDelegate?
    

    @Published var isAnyOffline = false
    @Published var canSetAsOffline = false
    @Published var isAnyDirectory = false
    @Published var isAllDirectory = false
    @Published var isAnyLocked = false
    @Published var canUnlock = true
    @Published var enableLock = false
    @Published var isSelectedEmpty = true
    
    let displayedButtons: [TabButton]

    init(controller: NCMainTabBarController?,
         delegate: HiDriveCollectionViewCommonSelectToolbarDelegate? = nil,
         displayedButtons: [TabButton] = [.share, .moveOrCopy, .delete, .download, .lockOrUnlock]) {
        self.delegate = delegate
        self.displayedButtons = displayedButtons
        self.controller = controller
        setupHostingController()
        setupOrientationObserver()
    }
    
    private func setupOrientationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func deviceOrientationDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateToolbarFrame()
        }
    }
    
    private func setupHostingController() {
        let rootView = HiDriveCollectionViewCommonSelectToolbarView(tabBarSelect: self)
        hostingController = UIHostingController(rootView: rootView)
        hostingController?.view.isHidden = true
    }

    private func updateToolbarFrame() {
        guard let controller = self.controller,
                let hostingController = self.hostingController else {
            return
        }
        
        hostingController.view.frame = controller.tabBar.frame
        hostingController.view.backgroundColor = .clear
    }
    
    func show() {
        guard let hostingController, let currentViewController = controller?.currentViewController() else { return }
        
        if hostingController.view.isHidden {
            delegate?.toolbarWillAppear()
            currentViewController.view.addSubview(hostingController.view)
            
            updateToolbarFrame()
            animateToolbarAppearance(for: hostingController)
        }
    }
    
    private func animateToolbarAppearance(for hostingController: UIViewController) {
        hostingController.view.isHidden = false
        hostingController.view.transform = CGAffineTransform(translationX: 0, y: hostingController.view.frame.height)
        
        UIView.animate(withDuration: 0.2) {
            hostingController.view.transform = .identity
        }
    }

    func hide() {
        delegate?.toolbarWillDisappear()
        hostingController?.view.isHidden = true
    }

    func isHidden() -> Bool {
        return hostingController?.view.isHidden ?? false
    }

    func update(fileSelect: [String], metadatas: [tableMetadata]? = nil, userId: String? = nil) {
        if let metadatas {
            isAnyOffline = false
            canSetAsOffline = true
            isAnyDirectory = false
            isAllDirectory = true
            isAnyLocked = false
            canUnlock = true

            for metadata in metadatas {
                if metadata.directory {
                    isAnyDirectory = true
                } else {
                    isAllDirectory = false
                }

                if !metadata.canSetAsAvailableOffline {
                    canSetAsOffline = false
                }

                if metadata.lock {
                    isAnyLocked = true
                    if metadata.lockOwner != userId {
                        canUnlock = false
                    }
                }

                guard !isAnyOffline else { continue }

                if metadata.directory,
                   let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@",
                                                                                                    metadata.account,
                                                                                                    metadata.serverUrl + "/" + metadata.fileName)) {
                    isAnyOffline = directory.offline
                } else if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                    isAnyOffline = localFile.offline
                } // else: file is not offline, continue
            }
            enableLock = !isAnyDirectory && canUnlock && !NCCapabilities.shared.getCapabilities(account: controller?.account).capabilityFilesLockVersion.isEmpty
        }
        isSelectedEmpty = fileSelect.isEmpty
    }
    
    private func updateOfflineStatus(for metadata: tableMetadata) {
        if metadata.directory,
           let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl + "/" + metadata.fileName)) {
            isAnyOffline = directory.offline
        } else if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            isAnyOffline = localFile.offline
        }
    }
    
    func onViewWillLayoutSubviews() {
        updateToolbarFrame()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
