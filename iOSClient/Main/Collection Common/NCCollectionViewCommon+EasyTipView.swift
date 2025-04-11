//
//  NCCollectionViewCommon+EasyTipView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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
import UIKit
import EasyTipView

extension NCCollectionViewCommon: EasyTipViewDelegate {
    func showTipAccounts() {
        guard !session.account.isEmpty,
              self is NCFiles,
              self.view.window != nil,
              !NCBrandOptions.shared.disable_multiaccount,
              self.serverUrl == utilityFileSystem.getHomeServer(session: session),
              let view = self.navigationItem.leftBarButtonItem?.customView,
              !database.tipExists(global.tipAccountRequest) else { return }
        var preferences = EasyTipView.Preferences()

        preferences.drawing.foregroundColor = .white
        preferences.drawing.backgroundColor = .lightGray
        preferences.drawing.textAlignment = .left
        preferences.drawing.arrowPosition = .top
        preferences.drawing.cornerRadius = 10

        preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: 100)
        preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -100)
        preferences.animating.showInitialAlpha = 0
        preferences.animating.showDuration = 1.5
        preferences.animating.dismissDuration = 1.5

        if tipViewAccounts == nil {
            tipViewAccounts = EasyTipView(text: NSLocalizedString("_tip_accountrequest_", comment: ""), preferences: preferences, delegate: self, tip: global.tipAccountRequest)
            tipViewAccounts?.show(forView: view)
        }
    }

    func showTipAutoUpload() {
        guard !session.account.isEmpty,
              self.view.window != nil,
              self.serverUrl == utilityFileSystem.getHomeServer(session: session),
              !database.tipExists(global.tipAutoUpload) else { return }

        var preferences = EasyTipView.Preferences()

        preferences.drawing.foregroundColor = .white
        preferences.drawing.backgroundColor = .lightGray
        preferences.drawing.textAlignment = .left
        preferences.drawing.arrowPosition = .top
        preferences.drawing.cornerRadius = 10
        preferences.drawing.arrowPosition = EasyTipView.ArrowPosition.bottom

        preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: 100)
        preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -100)
        preferences.animating.showInitialAlpha = 0
        preferences.animating.showDuration = 1.5
        preferences.animating.dismissDuration = 1.5

        if tipViewAutoUpload == nil {
            tipViewAutoUpload = EasyTipView(text: NSLocalizedString("_tip_autoupload_", comment: ""), preferences: preferences, delegate: self, tip: global.tipAutoUpload)
            if  let item = controller?.tabBar.items?.first(where: { $0.tag == 104 }),
                let view = controller?.tabBar.viewForItem(item) {
                tipViewAutoUpload?.show(forView: view)
            }
        }
    }

    func easyTipViewDidTap(_ tipView: EasyTipView) {
        if tipView.tip == global.tipAccountRequest {
            database.addTip(global.tipAccountRequest)
        }
        if tipView.tip == global.tipAutoUpload {
            database.addTip(global.tipAutoUpload)
        }
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) { }

    func dismissTip() {
        if !database.tipExists(global.tipAccountRequest) {
            database.addTip(global.tipAccountRequest)
        }
        if !database.tipExists(global.tipAutoUpload) {
            database.addTip(global.tipAutoUpload)
        }
        tipViewAccounts?.dismiss()
        tipViewAccounts = nil
        tipViewAutoUpload?.dismiss()
        tipViewAutoUpload = nil
    }
}
