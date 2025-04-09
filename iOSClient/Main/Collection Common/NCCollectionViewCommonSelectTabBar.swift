//
//  NCCollectionViewCommonSelectionTabBar.swift
//  Nextcloud
//
//  Created by Milen on 01.02.24.
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

import Foundation
import SwiftUI

protocol NCCollectionViewCommonSelectToolbarDelegate: AnyObject {
    func selectAll()
    func delete()
    func move()
    func share()
    func saveAsAvailableOffline(isAnyOffline: Bool)
    func lock(isAnyLocked: Bool)
    func toolbarWillAppear()
    func toolbarWillDisappear()
}

class NCCollectionViewCommonSelectToolbar: ObservableObject {
    enum TabButton {
        case share
        case moveOrCopy
        case delete
        case download
        case lockOrUnlock
    }
    
    private(set) var hostingController: UIViewController?
    open weak var delegate: NCCollectionViewCommonSelectToolbarDelegate?

    @Published var isAnyOffline = false
    @Published var canSetAsOffline = false
    @Published var isAnyDirectory = false
    @Published var isAllDirectory = false
    @Published var isAnyLocked = false
    @Published var canUnlock = true
    @Published var enableLock = false
    @Published var isSelectedEmpty = true
    
    let displayedButtons: [TabButton]

    init(delegate: NCCollectionViewCommonSelectToolbarDelegate? = nil,
         displayedButtons: [TabButton] = [.share, .moveOrCopy, .delete, .download, .lockOrUnlock]) {
        self.delegate = delegate
        self.displayedButtons = displayedButtons
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
        if hostingController != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let hostingController = self.hostingController else { return }
                self.updateToolbarFrame(for: hostingController)
            }
        }
    }
    
    private func setupHostingController() {
        let rootView = NCCollectionViewCommonSelectToolbarView(tabBarSelect: self)
        hostingController = UIHostingController(rootView: rootView)
        hostingController?.view.isHidden = true
    }

    private func updateToolbarFrame(for hostingController: UIViewController) {
        let screenSize = UIScreen.main.bounds.size
		let height = AppScreenConstants.toolbarHeight
        let frame = CGRect(x: 0, y: screenSize.height - height, width: screenSize.width, height: height)
        
        hostingController.view.frame = frame
        hostingController.view.backgroundColor = .clear
    }
    
    func show() {
        guard let hostingController, let controller = getTopViewController() else { return }
        
        if hostingController.view.isHidden {
            delegate?.toolbarWillAppear()
            controller.view.addSubview(hostingController.view)
            
            updateToolbarFrame(for: hostingController)
            animateToolbarAppearance(for: hostingController)
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        var topController: UIViewController? = keyWindow.rootViewController
        
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        return topController
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

    func update(selectOcId: [String], metadatas: [tableMetadata]? = nil, userId: String? = nil) {
        guard let metadatas else {
            isSelectedEmpty = selectOcId.isEmpty
            return
        }
        
        resetStates()
        
        for metadata in metadatas {
            updateStates(for: metadata, userId: userId)
        }
        
        enableLock = !isAnyDirectory && canUnlock && !NCGlobal.shared.capabilityFilesLockVersion.isEmpty
        isSelectedEmpty = selectOcId.isEmpty
    }
    
    private func resetStates() {
        isAnyOffline = false
        canSetAsOffline = true
        isAnyDirectory = false
        isAllDirectory = true
        isAnyLocked = false
        canUnlock = true
    }
    
    private func updateStates(for metadata: tableMetadata, userId: String?) {
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
        
        if !isAnyOffline {
            updateOfflineStatus(for: metadata)
        }
    }
    
    private func updateOfflineStatus(for metadata: tableMetadata) {
        if metadata.directory,
           let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl + "/" + metadata.fileName)) {
            isAnyOffline = directory.offline
        } else if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            isAnyOffline = localFile.offline
        }
    }
}

extension NCCollectionViewCommonSelectToolbarDelegate {
    func selectAll() { }
    func delete() { }
    func move() { }
    func share() { }
    func saveAsAvailableOffline(isAnyOffline: Bool) { }
    func lock(isAnyLocked: Bool) { }
}
