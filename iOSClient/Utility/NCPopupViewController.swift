//
//  NCPopupViewController.swift
//
//  Based on EzPopup by Huy Nguyen
//  Modified by Marino Faggiana for Nextcloud progect.
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

import UIKit

public protocol NCPopupViewControllerDelegate: AnyObject {

    func popupViewControllerDidDismissByTapGesture(_ sender: NCPopupViewController)
}

// optional func
public extension NCPopupViewControllerDelegate {
    func popupViewControllerDidDismissByTapGesture(_ sender: NCPopupViewController) {}
}

public class NCPopupViewController: UIViewController {

    private var centerYConstraint: NSLayoutConstraint?

    // Popup width, it's nil if width is determined by view's intrinsic size
    private(set) public var popupWidth: CGFloat?

    // Popup height, it's nil if width is determined by view's intrinsic size
    private(set) public var popupHeight: CGFloat?

    // Background alpha, default is 0.3
    public var backgroundAlpha: CGFloat = 0.2

    // Background color, default is black
    public var backgroundColor = UIColor.black

    // Allow tap outside popup to dismiss, default is true
    public var canTapOutsideToDismiss = true

    // Corner radius, default is 10 (0 no rounded corner)
    public var cornerRadius: CGFloat = 10

    // Shadow enabled, default is true
    public var shadowEnabled = true

    // Border enabled, default is false
    public var borderEnabled = false

    // Move the popup position H when show/hide keyboard
    public var keyboardPosizionEnabled = true

    // The pop up view controller. It's not mandatory.
    private(set) public var contentController: UIViewController?

    // The pop up view
    private(set) public var contentView: UIView?

    // The delegate to receive pop up event
    public weak var delegate: NCPopupViewControllerDelegate?

    private var containerView = UIView()

    // MARK: - View Life Cycle

    // NOTE: Don't use this init method
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    /**
     Init with content view controller. Your pop up content is a view controller (easiest way to design it is using storyboard)
     - Parameters:
        - contentController: Popup content view controller
        - popupWidth: Width of popup content. If it isn't set, width will be determine by popup content view intrinsic size.
        - popupHeight: Height of popup content. If it isn't set, height will be determine by popup content view intrinsic size.
     */
    public init(contentController: UIViewController, popupWidth: CGFloat? = nil, popupHeight: CGFloat? = nil) {
        super.init(nibName: nil, bundle: nil)

        self.contentController = contentController
        self.contentView = contentController.view
        self.popupWidth = popupWidth
        self.popupHeight = popupHeight

        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    /**
     Init with content view
     - Parameters:
         - contentView: Popup content view
         - popupWidth: Width of popup content. If it isn't set, width will be determine by popup content view intrinsic size.
         - popupHeight: Height of popup content. If it isn't set, height will be determine by popup content view intrinsic size.
     */

    public init(contentView: UIView, popupWidth: CGFloat? = nil, popupHeight: CGFloat? = nil) {
        super.init(nibName: nil, bundle: nil)

        self.contentView = contentView
        self.popupWidth = popupWidth
        self.popupHeight = popupHeight

        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupViews()
        addDismissGesture()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - Setup

    private func addDismissGesture() {

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissTapGesture(gesture:)))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }

    private func setupUI() {

        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView?.translatesAutoresizingMaskIntoConstraints = false

        view.backgroundColor = backgroundColor.withAlphaComponent(backgroundAlpha)

        if cornerRadius > 0 {
            contentView?.layer.cornerRadius = cornerRadius
            contentView?.layer.masksToBounds = true
        }

        if shadowEnabled {
            containerView.layer.shadowOpacity = 0.5
            containerView.layer.shadowColor = UIColor.black.cgColor
            containerView.layer.shadowOffset = CGSize(width: 5, height: 5)
            containerView.layer.shadowRadius = 5
        }

        if borderEnabled {
            containerView.layer.cornerRadius = cornerRadius
            containerView.layer.borderWidth = 0.3
            containerView.layer.borderColor = NCBrandColor.shared.textColor2.cgColor
        }
    }

    private func setupViews() {

        if let contentController = contentController {
            addChild(contentController)
        }

        addViews()
        addSizeConstraints()
        addCenterPositionConstraints()
    }

    private func addViews() {

        view.addSubview(containerView)

        if let contentView = contentView {
            containerView.addSubview(contentView)

            let topConstraint = NSLayoutConstraint(item: contentView, attribute: .top, relatedBy: .equal, toItem: containerView, attribute: .top, multiplier: 1, constant: 0)
            let leftConstraint = NSLayoutConstraint(item: contentView, attribute: .left, relatedBy: .equal, toItem: containerView, attribute: .left, multiplier: 1, constant: 0)
            let bottomConstraint = NSLayoutConstraint(item: contentView, attribute: .bottom, relatedBy: .equal, toItem: containerView, attribute: .bottom, multiplier: 1, constant: 0)
            let rightConstraint = NSLayoutConstraint(item: contentView, attribute: .right, relatedBy: .equal, toItem: containerView, attribute: .right, multiplier: 1, constant: 0)
            NSLayoutConstraint.activate([topConstraint, leftConstraint, bottomConstraint, rightConstraint])
        }
    }

    // MARK: - Add constraints

    private func addSizeConstraints() {

        if let popupWidth = popupWidth {
            let widthConstraint = NSLayoutConstraint(item: containerView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: popupWidth)
            NSLayoutConstraint.activate([widthConstraint])
        }

        if let popupHeight = popupHeight {
            let heightConstraint = NSLayoutConstraint(item: containerView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: popupHeight)
            NSLayoutConstraint.activate([heightConstraint])
        }
    }

    private func addCenterPositionConstraints() {

        let centerXConstraint = NSLayoutConstraint(item: containerView, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: 0)
        centerYConstraint = NSLayoutConstraint(item: containerView, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1, constant: 0)
        NSLayoutConstraint.activate([centerXConstraint, centerYConstraint!])
    }

    // MARK: -

    func addPath() {

        let balloon = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 250))
        balloon.backgroundColor = UIColor.clear

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 200, y: 0))
        path.addLine(to: CGPoint(x: 200, y: 200))

        // Draw arrow
        path.addLine(to: CGPoint(x: 120, y: 200))
        path.addLine(to: CGPoint(x: 100, y: 250))
        path.addLine(to: CGPoint(x: 80, y: 200))

        path.addLine(to: CGPoint(x: 0, y: 200))
        path.close()

        let shape = CAShapeLayer()
        // shape.backgroundColor = UIColor.blue.cgColor
        shape.fillColor = UIColor.blue.cgColor
        shape.path = path.cgPath
        balloon.layer.addSublayer(shape)

        // [self.view addSubview:balloonView];

    }

    // MARK: - Actions

    @objc func dismissTapGesture(gesture: UIGestureRecognizer) {
        dismiss(animated: true) {
            self.delegate?.popupViewControllerDidDismissByTapGesture(self)
        }
    }

    // MARK: - Keyboard notification

    @objc internal func keyboardWillShow(_ notification: Notification?) {

        var keyboardSize = CGSize.zero

        if let info = notification?.userInfo {

            let frameEndUserInfoKey = UIResponder.keyboardFrameEndUserInfoKey

            //  Getting UIKeyboardSize.
            if let keyboardFrame = info[frameEndUserInfoKey] as? CGRect {

                let screenSize = UIScreen.main.bounds

                // Calculating actual keyboard displayed size, keyboard frame may be different when hardware keyboard is attached (Bug ID: #469) (Bug ID: #381)
                let intersectRect = keyboardFrame.intersection(screenSize)

                if intersectRect.isNull {
                    keyboardSize = CGSize(width: screenSize.size.width, height: 0)
                } else {
                    keyboardSize = intersectRect.size
                }

                if keyboardPosizionEnabled {

                    let popupDiff = screenSize.height - ((screenSize.height - (popupHeight ?? 0)) / 2)
                    let keyboardDiff = screenSize.height - keyboardSize.height
                    let diff = popupDiff - keyboardDiff

                    if centerYConstraint != nil && diff > 0 {
                        centerYConstraint?.constant = -(diff + 15)
                    }
                }
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {

        if keyboardPosizionEnabled {
            if centerYConstraint != nil {
                centerYConstraint?.constant = 0
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension NCPopupViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchView = touch.view, canTapOutsideToDismiss else {
            return false
        }

        return !touchView.isDescendant(of: containerView)
    }
}
