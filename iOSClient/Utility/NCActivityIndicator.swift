//
//  NCActivityIndicator.swift
// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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

    @objc func startActivity(backgroundView: UIView? = nil, style: UIActivityIndicatorView.Style, blurEffect: Bool = true) {
        start(backgroundView: backgroundView, style: style, blurEffect: blurEffect)
    }

    func start(backgroundView: UIView? = nil, bottom: CGFloat? = nil, top: CGFloat? = nil, style: UIActivityIndicatorView.Style = .large, blurEffect: Bool = true) {

        if self.activityIndicator != nil { stop() }

        DispatchQueue.main.async {

            self.activityIndicator = UIActivityIndicatorView(style: style)
            guard let activityIndicator = self.activityIndicator, self.viewBackgroundActivityIndicator == nil else { return }

            activityIndicator.color = NCBrandColor.shared.textColor
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

            if backgroundView == nil, blurEffect {
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {

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
