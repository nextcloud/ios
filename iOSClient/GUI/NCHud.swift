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
    private var view: UIView?

    public init(_ view: UIView? = nil) {
        if let view {
            self.view = view
        }
        super.init()
    }

    func initHud(view: UIView? = nil, text: String? = nil, detailText: String? = nil) {
        DispatchQueue.main.async {
            if let view {
                self.view = view
            }

            self.hud.indicatorView = JGProgressHUDIndicatorView()

            self.hud.textLabel.text = text
            self.hud.textLabel.textColor = NCBrandColor.shared.iconImageColor

            self.hud.detailTextLabel.text = detailText
            self.hud.detailTextLabel.textColor = NCBrandColor.shared.iconImageColor2

            if let view = self.view {
                self.hud.show(in: view)
            }
        }
    }

    func initHudRing(view: UIView? = nil, text: String? = nil, detailText: String? = nil, tapToCancelDetailText: Bool = false, tapOperation: (() -> Void)? = nil) {
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
            self.hud.progress = 0.0

            let indicatorView = self.hud.indicatorView as? JGProgressHUDRingIndicatorView
            indicatorView?.ringWidth = 1.5
            indicatorView?.ringColor = NCBrandColor.shared.iconImageColor

            self.hud.textLabel.text = text
            self.hud.textLabel.textColor = NCBrandColor.shared.iconImageColor

            if tapToCancelDetailText {
                self.hud.detailTextLabel.text = NSLocalizedString("_tap_to_cancel_", comment: "")
            } else {
                self.hud.detailTextLabel.text = detailText
            }
            self.hud.detailTextLabel.textColor = NCBrandColor.shared.iconImageColor2

            if let view = self.view {
                self.hud.show(in: view)
            }
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            self.hud.dismiss()
        }
    }

    func show() {
        DispatchQueue.main.async {
            if let view = self.view {
                self.hud.show(in: view)
            }
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

    func error(text: String?) {
        DispatchQueue.main.async {
            self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
            self.hud.indicatorView?.tintColor = .red
            self.hud.textLabel.text = text
            self.hud.dismiss(afterDelay: 2.0)
        }
    }

    func setText(text: String?, detailText: String? = nil) {
        DispatchQueue.main.async {
            self.hud.textLabel.text = text
            self.hud.detailTextLabel.text = detailText
        }
    }
}
