//
//  PopupViewController.swift
//  EzPopup
//
//  Created by Huy Nguyen on 6/4/18.
//

import UIKit

public protocol PopupViewControllerDelegate: class {
    
    /// It is called when pop up is dismissed by tap outside
    func popupViewControllerDidDismissByTapGesture(_ sender: PopupViewController)
}

// optional func
public extension PopupViewControllerDelegate {
    func popupViewControllerDidDismissByTapGesture(_ sender: PopupViewController) {}
}

public class PopupViewController: UIViewController {
    
    public enum PopupPosition {
        /// Align center X, center Y with offset param
        case center(CGPoint?)
        
        /// Top left anchor point with offset param
        case topLeft(CGPoint?)
        
        /// Top right anchor point with offset param
        case topRight(CGPoint?)
        
        /// Bottom left anchor point with offset param
        case bottomLeft(CGPoint?)
        
        /// Bottom right anchor point with offset param
        case bottomRight(CGPoint?)
        
        /// Top anchor, align center X with top padding param
        case top(CGFloat)
        
        /// Left anchor, align center Y with left padding param
        case left(CGFloat)
        
        /// Bottom anchor, align center X with bottom padding param
        case bottom(CGFloat)
        
        /// Right anchor, align center Y with right padding param
        case right(CGFloat)
    }
    
    /// Popup width, it's nil if width is determined by view's intrinsic size
    private(set) public var popupWidth: CGFloat?
    
    /// Popup height, it's nil if width is determined by view's intrinsic size
    private(set) public var popupHeight: CGFloat?
    
    /// Popup position, default is center
    private(set) public var position: PopupPosition = .center(nil)
    
    /// Background alpha, default is 0.5
    public var backgroundAlpha: CGFloat = 0.5
    
    /// Background color, default is black
    public var backgroundColor = UIColor.black
    
    /// Allow tap outside popup to dismiss, default is true
    public var canTapOutsideToDismiss = true
    
    /// Corner radius, default is 0 (no rounded corner)
    public var cornerRadius: CGFloat = 0
    
    /// Shadow enabled, default is true
    public var shadowEnabled = true
    
    /// The pop up view controller. It's not mandatory.
    private(set) public var contentController: UIViewController?
    
    /// The pop up view
    private(set) public var contentView: UIView?
    
    /// The delegate to receive pop up event
    public weak var delegate: PopupViewControllerDelegate?
    
    private var containerView = UIView()
    
    // MARK: -
    
    /// NOTE: Don't use this init method
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    /**
     Init with content view controller. Your pop up content is a view controller (easiest way to design it is using storyboard)
     - Parameters:
        - contentController: Popup content view controller
        - position: Position of popup content, default is center
        - popupWidth: Width of popup content. If it isn't set, width will be determine by popup content view intrinsic size.
        - popupHeight: Height of popup content. If it isn't set, height will be determine by popup content view intrinsic size.
     */
    public init(contentController: UIViewController, position: PopupPosition = .center(nil), popupWidth: CGFloat? = nil, popupHeight: CGFloat? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.contentController = contentController
        self.contentView = contentController.view
        self.popupWidth = popupWidth
        self.popupHeight = popupHeight
        self.position = position
        
        commonInit()
    }
    
    /**
     Init with content view
     - Parameters:
         - contentView: Popup content view
         - position: Position of popup content, default is center
         - popupWidth: Width of popup content. If it isn't set, width will be determine by popup content view intrinsic size.
         - popupHeight: Height of popup content. If it isn't set, height will be determine by popup content view intrinsic size.
     */
    public init(contentView: UIView, position: PopupPosition = .center(nil), popupWidth: CGFloat? = nil, popupHeight: CGFloat? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.contentView = contentView
        self.popupWidth = popupWidth
        self.popupHeight = popupHeight
        self.position = position
        
        commonInit()
    }
    
    private func commonInit() {
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupViews()
        addDismissGesture()
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
    }
    
    private func setupViews() {
        if let contentController = contentController {
            addChild(contentController)
        }
        
        addViews()
        addSizeConstraints()
        addPositionConstraints()
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
    
    private func addPositionConstraints() {
        switch position {
        case .center(let offset):
            addCenterPositionConstraints(offset: offset)
            
        case .topLeft(let offset):
            addTopLeftPositionConstraints(offset: offset)
            
        case .topRight(let offset):
            addTopRightPositionConstraints(offset: offset)
            
        case .bottomLeft(let offset):
            addBottomLeftPositionConstraints(offset: offset)
            
        case .bottomRight(let offset):
            addBottomRightPositionConstraints(offset: offset)
            
        case .top(let offset):
            addTopPositionConstraints(offset: offset)
            
        case .left(let offset):
            addLeftPositionConstraints(offset: offset)
            
        case .bottom(let offset):
            addBottomPositionConstraints(offset: offset)
            
        case .right(let offset):
            addRightPositionConstraints(offset: offset)
        }
    }
    
    private func addCenterPositionConstraints(offset: CGPoint?) {
        let centerXConstraint = NSLayoutConstraint(item: containerView, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: offset?.x ?? 0)
        let centerYConstraint = NSLayoutConstraint(item: containerView, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1, constant: offset?.y ?? 0)
        NSLayoutConstraint.activate([centerXConstraint, centerYConstraint])
    }
    
    private func addTopLeftPositionConstraints(offset: CGPoint?) {
        let topConstraint = NSLayoutConstraint(item: containerView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: offset?.y ?? 0)
        let leftConstraint = NSLayoutConstraint(item: containerView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1, constant: offset?.x ?? 0)
        NSLayoutConstraint.activate([topConstraint, leftConstraint])
    }
    
    private func addTopRightPositionConstraints(offset: CGPoint?) {
        let topConstraint = NSLayoutConstraint(item: containerView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: offset?.y ?? 0)
        let rightConstraint = NSLayoutConstraint(item: view as Any, attribute: .right, relatedBy: .equal, toItem: containerView, attribute: .right, multiplier: 1, constant: offset?.x ?? 0)
        NSLayoutConstraint.activate([topConstraint, rightConstraint])
    }
    
    private func addBottomLeftPositionConstraints(offset: CGPoint?) {
        let bottomConstraint = NSLayoutConstraint(item: view as Any, attribute: .bottom, relatedBy: .equal, toItem: containerView, attribute: .bottom, multiplier: 1, constant: offset?.y ?? 0)
        let leftConstraint = NSLayoutConstraint(item: containerView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1, constant: offset?.x ?? 0)
        NSLayoutConstraint.activate([bottomConstraint, leftConstraint])
    }
    
    private func addBottomRightPositionConstraints(offset: CGPoint?) {
        let bottomConstraint = NSLayoutConstraint(item: view as Any, attribute: .bottom, relatedBy: .equal, toItem: containerView, attribute: .bottom, multiplier: 1, constant: offset?.y ?? 0)
        let rightConstraint = NSLayoutConstraint(item: view as Any, attribute: .right, relatedBy: .equal, toItem: containerView, attribute: .right, multiplier: 1, constant: offset?.x ?? 0)
        NSLayoutConstraint.activate([bottomConstraint, rightConstraint])
    }
    
    private func addTopPositionConstraints(offset: CGFloat) {
        let topConstraint = NSLayoutConstraint(item: containerView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: offset)
        let centerXConstraint = NSLayoutConstraint(item: view as Any, attribute: .centerX, relatedBy: .equal, toItem: containerView, attribute: .centerX, multiplier: 1, constant: 0)
        NSLayoutConstraint.activate([topConstraint, centerXConstraint])
    }
    
    private func addLeftPositionConstraints(offset: CGFloat) {
        let leftConstraint = NSLayoutConstraint(item: containerView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1, constant: offset)
        let centerYConstraint = NSLayoutConstraint(item: view as Any, attribute: .centerY, relatedBy: .equal, toItem: containerView, attribute: .centerY, multiplier: 1, constant: 0)
        NSLayoutConstraint.activate([leftConstraint, centerYConstraint])
    }
    
    private func addBottomPositionConstraints(offset: CGFloat) {
        let bottomConstraint = NSLayoutConstraint(item: view as Any, attribute: .bottom, relatedBy: .equal, toItem: containerView, attribute: .bottom, multiplier: 1, constant: offset)
        let centerXConstraint = NSLayoutConstraint(item: view as Any, attribute: .centerX, relatedBy: .equal, toItem: containerView, attribute: .centerX, multiplier: 1, constant: 0)
        NSLayoutConstraint.activate([bottomConstraint, centerXConstraint])
    }
    
    private func addRightPositionConstraints(offset: CGFloat) {
        let rightConstraint = NSLayoutConstraint(item: view as Any, attribute: .right, relatedBy: .equal, toItem: containerView, attribute: .right, multiplier: 1, constant: offset)
        let centerXConstraint = NSLayoutConstraint(item: view as Any, attribute: .centerY, relatedBy: .equal, toItem: containerView, attribute: .centerY, multiplier: 1, constant: 0)
        NSLayoutConstraint.activate([rightConstraint, centerXConstraint])
    }

    // MARK: - Actions
    
    @objc func dismissTapGesture(gesture: UIGestureRecognizer) {
        dismiss(animated: true) {
            self.delegate?.popupViewControllerDidDismissByTapGesture(self)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension PopupViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchView = touch.view, canTapOutsideToDismiss else {
            return false
        }
        
        return !touchView.isDescendant(of: containerView)
    }
}
