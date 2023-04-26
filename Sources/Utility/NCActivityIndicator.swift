//
//  NCActivityIndicator.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 11/08/22.
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
import UIKit

class NCActivityIndicator: NSObject {
    @objc static let shared: NCActivityIndicator = {
        let instance = NCActivityIndicator()
        return instance
    }()

    private var activityIndicator: UIActivityIndicatorView?
    private var viewActivityIndicator: UIView?
    private var viewBackgroundActivityIndicator: UIView?

    @objc func startActivity(backgroundView: UIView?, style: UIActivityIndicatorView.Style) {
        start(backgroundView: backgroundView, style: style)
    }

    func start(backgroundView: UIView? = nil, bottom: CGFloat? = nil, top: CGFloat? = nil, style: UIActivityIndicatorView.Style = .large) {

        if self.activityIndicator != nil { stop() }

        DispatchQueue.main.async {

            self.activityIndicator = UIActivityIndicatorView(style: style)
            guard let activityIndicator = self.activityIndicator, self.viewBackgroundActivityIndicator == nil else { return }

            activityIndicator.color = .label
            activityIndicator.hidesWhenStopped = true
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false

            var sizeActivityIndicator = activityIndicator.frame.height
            if backgroundView == nil {
                sizeActivityIndicator += 50
            }

            self.viewActivityIndicator = UIView(frame: CGRect(x: 0, y: 0, width: sizeActivityIndicator, height: sizeActivityIndicator))
            self.viewActivityIndicator?.translatesAutoresizingMaskIntoConstraints = false
            self.viewActivityIndicator?.layer.cornerRadius = 10
            self.viewActivityIndicator?.layer.masksToBounds = true
            self.viewActivityIndicator?.backgroundColor = .clear

#if !EXTENSION
            if backgroundView == nil {
                if let window = (UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.first { $0.isKeyWindow }) {
                    self.viewBackgroundActivityIndicator?.removeFromSuperview()
                    self.viewBackgroundActivityIndicator = NCViewActivityIndicator(frame: window.bounds)
                    window.addSubview(self.viewBackgroundActivityIndicator!)
                    self.viewBackgroundActivityIndicator?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    self.viewBackgroundActivityIndicator?.backgroundColor = .clear
                }
            } else {
                self.viewBackgroundActivityIndicator = backgroundView
            }
#else
            self.viewBackgroundActivityIndicator = backgroundView
#endif

            // VIEW ACTIVITY INDICATOR

            guard let viewActivityIndicator = self.viewActivityIndicator else { return }
            viewActivityIndicator.addSubview(activityIndicator)

            if backgroundView == nil {
                let blurEffect = UIBlurEffect(style: .regular)
                let blurEffectView = UIVisualEffectView(effect: blurEffect)
                blurEffectView.frame = viewActivityIndicator.frame
                viewActivityIndicator.insertSubview(blurEffectView, at: 0)
            }

            NSLayoutConstraint.activate([
                viewActivityIndicator.widthAnchor.constraint(equalToConstant: sizeActivityIndicator),
                viewActivityIndicator.heightAnchor.constraint(equalToConstant: sizeActivityIndicator),
                activityIndicator.centerXAnchor.constraint(equalTo: viewActivityIndicator.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: viewActivityIndicator.centerYAnchor)
            ])

            // BACKGROUD VIEW ACTIVITY INDICATOR

            guard let viewBackgroundActivityIndicator = self.viewBackgroundActivityIndicator else { return }
            viewBackgroundActivityIndicator.addSubview(viewActivityIndicator)

            if let constant = bottom {
                viewActivityIndicator.bottomAnchor.constraint(equalTo: viewBackgroundActivityIndicator.bottomAnchor, constant: constant).isActive = true
            } else if let constant = top {
                viewActivityIndicator.topAnchor.constraint(equalTo: viewBackgroundActivityIndicator.topAnchor, constant: constant).isActive = true
            } else {
                viewActivityIndicator.centerYAnchor.constraint(equalTo: viewBackgroundActivityIndicator.centerYAnchor).isActive = true
            }
            viewActivityIndicator.centerXAnchor.constraint(equalTo: viewBackgroundActivityIndicator.centerXAnchor).isActive = true

            activityIndicator.startAnimating()
        }
    }

    @objc func stop() {

        DispatchQueue.main.async {

            self.activityIndicator?.stopAnimating()
            self.activityIndicator?.removeFromSuperview()
            self.activityIndicator = nil

            self.viewActivityIndicator?.removeFromSuperview()
            self.viewActivityIndicator = nil

            if self.viewBackgroundActivityIndicator is NCViewActivityIndicator {
                self.viewBackgroundActivityIndicator?.removeFromSuperview()
            }
            self.viewBackgroundActivityIndicator = nil
        }
    }
}

class NCViewActivityIndicator: UIView {

    // MARK: - View Life Cycle

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
