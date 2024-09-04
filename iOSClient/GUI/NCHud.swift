//
//  NCHud.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 04/09/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import JGProgressHUD

public class NCHud: NSObject {
    public let hud = JGProgressHUD()
    var account: String

    public init(account: String) {
        self.account = account
        super.init()
    }

    func initIndicatorView(view: UIView, textLabel: String = "", detailTextLabel: String = "", tapOperation: (() -> Void)?) {

        DispatchQueue.main.async {

            self.hud.tapOnHUDViewBlock = { hud in
                if let tapOperation {
                    tapOperation()
                    hud.dismiss()
                }
            }

            self.hud.indicatorView = JGProgressHUDRingIndicatorView()

            let indicatorView = self.hud.indicatorView as? JGProgressHUDRingIndicatorView
            indicatorView?.ringWidth = 1.5
            indicatorView?.ringColor = NCBrandColor.shared.getElement(account: self.account)

            self.hud.textLabel.text = textLabel
            self.hud.textLabel.textColor = NCBrandColor.shared.iconImageColor
            self.hud.detailTextLabel.text = detailTextLabel
            self.hud.detailTextLabel.textColor = NCBrandColor.shared.iconImageColor2

            self.hud.show(in: view)
        }
    }
}
