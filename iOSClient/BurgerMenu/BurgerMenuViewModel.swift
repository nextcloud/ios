//
//  BurgerMenuViewModel.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 29.07.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

protocol BurgerMenuViewModelDelegate: AnyObject {
    func burgerMenuViewModelDidHideMenu(_ viewModel: BurgerMenuViewModel)
    func burgerMenuViewModelWantsOpenRecent(_ viewModel: BurgerMenuViewModel)
    func burgerMenuViewModelWantsOpenOffline(_ viewModel: BurgerMenuViewModel)
    func burgerMenuViewModelWantsOpenDeletedFiles(_ viewModel: BurgerMenuViewModel)
    func burgerMenuViewModelWantsOpenSettings(_ viewModel: BurgerMenuViewModel)
}

class BurgerMenuViewModel: ObservableObject {
    weak var delegate: BurgerMenuViewModelDelegate?
    
    @Published var progressUsedSpace: Double = 0
    @Published var messageUsedSpace: String = ""
        
    @Published var isVisible: Bool = false
    
    private let database = NCManageDatabase.shared
    
    weak var controller: NCMainTabBarController?
    private var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }
    
    let appearingAnimationIntervalInSec = 0.5
    
    init(delegate: BurgerMenuViewModelDelegate?, controller: NCMainTabBarController?) {
        self.delegate = delegate
    }
    
    func showMenu() {
        progressUsedSpace = getUsedSpaceProgress()
        messageUsedSpace = getUsedSpaceMessage()
        isVisible = true
    }
    
    func hideMenu() {
        isVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(Int(appearingAnimationIntervalInSec*1000)))) {
            self.delegate?.burgerMenuViewModelDidHideMenu(self)
        }
    }
    
    func openRecent() {
        delegate?.burgerMenuViewModelWantsOpenRecent(self)
    }
    
    func openOffline() {
        delegate?.burgerMenuViewModelWantsOpenOffline(self)
    }
    
    func openDeletedFiles() {
        delegate?.burgerMenuViewModelWantsOpenDeletedFiles(self)
    }
    
    func openSettings() {
        delegate?.burgerMenuViewModelWantsOpenSettings(self)
    }
    
    private func getUsedSpaceMessage() -> String {
        guard let activeAccount = getActiveAccount() else {
            return ""
        }
        
        let utilityFileSystem = NCUtilityFileSystem()
        var quota = ""
        switch activeAccount.quotaTotal {
        case -1:
            quota = "0"
        case -2:
            quota = NSLocalizedString("_quota_space_unknown_", comment: "")
        case -3:
            quota = NSLocalizedString("_quota_space_unlimited_", comment: "")
        default:
            quota = utilityFileSystem.transformedSize(activeAccount.quotaTotal)
        }

        let quotaUsed: String = utilityFileSystem.transformedSize(activeAccount.quotaUsed)

        let messageUsed = String.localizedStringWithFormat(NSLocalizedString("_used_of_space_", tableName: nil, bundle: Bundle.main, value: "%@ of %@ used", comment: ""), quotaUsed, quota)
        return messageUsed
    }
    
    private func getUsedSpaceProgress() -> Double {
        if let activeAccount = getActiveAccount(), activeAccount.quotaRelative > 0 {
            return activeAccount.quotaRelative/100.0
        }
        return 0
    }
    
    private func getActiveAccount() -> tableAccount? {
        return self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account))
    }
}
