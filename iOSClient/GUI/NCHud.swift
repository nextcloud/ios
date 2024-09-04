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

class NCHud: NSObject {
    private let hud = JGProgressHUD()
    private var account: String
    private var view = UIView()

    public init(view: UIView? = nil, account: String) {
        if let view {
            self.view = view
        }
        self.account = account
        super.init()
    }

    func initIndicatorView(view: UIView? = nil, textLabel: String? = nil, detailTextLabel: String? = nil, tapToCancelText: Bool, tapOperation: (() -> Void)?) {
        DispatchQueue.main.async {
            self.hud.tapOnHUDViewBlock = { hud in
                if let tapOperation {
                    tapOperation()
                    hud.dismiss()
                }
            }

            if let view {
                self.view = view
            }

            self.hud.indicatorView = JGProgressHUDRingIndicatorView()

            let indicatorView = self.hud.indicatorView as? JGProgressHUDRingIndicatorView
            indicatorView?.ringWidth = 1.5
            indicatorView?.ringColor = NCBrandColor.shared.getElement(account: self.account)

            self.hud.textLabel.text = textLabel
            self.hud.textLabel.textColor = NCBrandColor.shared.iconImageColor

            if tapToCancelText {
                self.hud.detailTextLabel.text = NSLocalizedString("_tap_to_cancel_", comment: "")
            } else {
                self.hud.detailTextLabel.text = detailTextLabel
            }
            self.hud.detailTextLabel.textColor = NCBrandColor.shared.iconImageColor2

            self.hud.show(in: self.view)
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            self.hud.dismiss()
        }
    }

    func show() {
        DispatchQueue.main.async {
            self.hud.show(in: self.view)
        }
    }

    func progress(num: Float, total: Float) {
        DispatchQueue.main.async {
            self.hud.progress = num / total
        }
    }

    func progress(_ progress: Double) {
        DispatchQueue.main.async {
            self.hud.progress = Float(progress)
        }
    }

    func success() {
        DispatchQueue.main.async {
            self.hud.indicatorView = JGProgressHUDSuccessIndicatorView()
            self.hud.indicatorView?.tintColor = .green
            self.hud.textLabel.text = NSLocalizedString("_success_", comment: "")
            self.hud.detailTextLabel.text = nil
            self.hud.dismiss(afterDelay: 1.0)
        }
    }

    func error(textLabel: String?) {
        DispatchQueue.main.async {
            self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
            self.hud.indicatorView?.tintColor = .red
            self.hud.textLabel.text = textLabel
            self.hud.dismiss(afterDelay: 2.0)
        }
    }

    func setText(textLabel: String?, detailTextLabel: String? = nil) {
        DispatchQueue.main.async {
            self.hud.textLabel.text = textLabel
            self.hud.detailTextLabel.text = detailTextLabel
        }
    }
}
