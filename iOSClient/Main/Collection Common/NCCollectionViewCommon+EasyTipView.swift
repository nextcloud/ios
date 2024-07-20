//
//  NCCollectionViewCommon+EasyTipView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import EasyTipView

extension NCCollectionViewCommon: EasyTipViewDelegate {
    func showTip() {
        guard !appDelegate.account.isEmpty,
              self is NCFiles,
              self.view.window != nil,
              !NCBrandOptions.shared.disable_multiaccount,
              self.serverUrl == utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId),
              let view = self.navigationItem.leftBarButtonItem?.customView,
              !NCManageDatabase.shared.tipExists(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest) else { return }
        var preferences = EasyTipView.Preferences()

        preferences.drawing.foregroundColor = .white
        preferences.drawing.backgroundColor = NCBrandColor.shared.nextcloud
        preferences.drawing.textAlignment = .left
        preferences.drawing.arrowPosition = .top
        preferences.drawing.cornerRadius = 10

        preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: 100)
        preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -100)
        preferences.animating.showInitialAlpha = 0
        preferences.animating.showDuration = 1.5
        preferences.animating.dismissDuration = 1.5

        if appDelegate.tipView == nil {
            appDelegate.tipView = EasyTipView(text: NSLocalizedString("_tip_accountrequest_", comment: ""), preferences: preferences, delegate: self)
            appDelegate.tipView?.show(forView: view)
        }
    }

    func easyTipViewDidTap(_ tipView: EasyTipView) {
        NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest)
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) { }

    func dismissTip() {
        if !NCManageDatabase.shared.tipExists(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest) {
            NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCCollectionViewCommonAccountRequest)
        }
        appDelegate.tipView?.dismiss()
        appDelegate.tipView = nil
    }
}
