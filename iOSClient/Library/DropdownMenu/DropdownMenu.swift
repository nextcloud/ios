//
//  DropdownMenu.swift
//  DropdownMenu
//
//  Created by Suric on 16/5/26.
//  Copyright © 2016年 teambition. All rights reserved.
//

import UIKit

public protocol DropdownMenuDelegate: class {
    func dropdownMenu(_ dropdownMenu: DropdownMenu, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    func dropdownMenu(_ dropdownMenu: DropdownMenu, cellForRowAt indexPath: IndexPath) -> UITableViewCell?
    func dropdownMenu(_ dropdownMenu: DropdownMenu, didSelectRowAt indexPath: IndexPath)
    func dropdownMenu(_ dropdownMenu: DropdownMenu, shouldUpdateSelectionAt indexPath: IndexPath) -> Bool
    func dropdownMenuCancel(_ dropdownMenu: DropdownMenu)
    func dropdownMenuWillDismiss(_ dropdownMenu: DropdownMenu)
    func dropdownMenuWillShow(_ dropdownMenu: DropdownMenu)
}

public extension DropdownMenuDelegate {
    func dropdownMenu(_ dropdownMenu: DropdownMenu, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) { }
    func dropdownMenu(_ dropdownMenu: DropdownMenu, cellForRowAt indexPath: IndexPath) -> UITableViewCell? { return nil }
    func dropdownMenu(_ dropdownMenu: DropdownMenu, didSelectRowAt indexPath: IndexPath) { }
    func dropdownMenu(_ dropdownMenu: DropdownMenu, shouldUpdateSelectionAt indexPath: IndexPath) -> Bool { return true }
    func dropdownMenuCancel(_ dropdownMenu: DropdownMenu) { }
    func dropdownMenuWillDismiss(_ dropdownMenu: DropdownMenu) { }
    func dropdownMenuWillShow(_ dropdownMenu: DropdownMenu) { }
}

open class DropdownMenu: UIView {
    fileprivate weak var navigationController: UINavigationController!
   
    fileprivate var sections: [DropdownSection] = []
    fileprivate var selectedIndexPath: [IndexPath]
    
    open var tableView: UITableView!
    fileprivate var barCoverView: UIView?
    open var isShow = false
    fileprivate var addedWindow: UIWindow?
    fileprivate var windowRootView: UIView?
    fileprivate var topConstraint: NSLayoutConstraint?
    fileprivate var navigationBarCoverViewHeightConstraint: NSLayoutConstraint?
    fileprivate let iPhoneXPortraitTopOffset: CGFloat = 88.0
    fileprivate let portraitTopOffset: CGFloat = 64.0
    fileprivate let landscapeTopOffset: CGFloat = 32.0
    fileprivate var topLayoutConstraintConstant: CGFloat {
        var offset: CGFloat = 0
        if !navigationController.isNavigationBarHidden {
          offset = navigationController.navigationBar.frame.height + navigationController.navigationBar.frame.origin.y
        }
        return offset + topOffsetY
    }
    
    open weak var delegate: DropdownMenuDelegate?
    open var token = ""
    open var animateDuration: TimeInterval = 0.25
    open var backgroudBeginColor: UIColor = UIColor.black.withAlphaComponent(0)
    open var backgroudEndColor = UIColor(white: 0, alpha: 0.4)
    open var rowHeight: CGFloat = 50
    open var sectionHeaderHeight: CGFloat = 44
    open var tableViewHeight: CGFloat = 0
    open var defaultBottonMargin: CGFloat = 0
    open var topOffsetY: CGFloat = 0
    
    open var textFont: UIFont = UIFont.systemFont(ofSize: 15.0)
    open var textColor: UIColor = UIColor(red: 56.0/255.0, green: 56.0/255.0, blue: 56.0/255.0, alpha: 1.0)
    open var highlightColor: UIColor = UIColor(red: 3.0/255.0, green: 169.0/255.0, blue: 244.0/255.0, alpha: 1.0)
    open var tableViewBackgroundColor: UIColor = UIColor(red: 242.0/255.0, green: 242.0/255.0, blue: 242.0/255.0, alpha: 1.0) {
        didSet {
            tableView.backgroundColor = tableViewBackgroundColor
        }
    }
    open var separatorStyle: UITableViewCell.SeparatorStyle = .singleLine {
        didSet {
            tableView.separatorStyle = separatorStyle
        }
    }
    open var tableViewSeperatorColor = UIColor(red: 217.0/255.0, green: 217.0/255.0, blue: 217.0/255.0, alpha: 1.0) {
        didSet {
            tableView.separatorColor = tableViewSeperatorColor
        }
    }
    open var zeroInsetSeperatorIndexPaths: [IndexPath] = []
    
    open var cellBackgroundColor = UIColor.white
    
    open var displaySelected: Bool = true
    open var displaySectionHeader: Bool = false
    open var displayNavigationBarCoverView: Bool = true
    
    // section header sytle
    open var sectionHeaderStyle: SectionHeaderStyle = SectionHeaderStyle()
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public init(navigationController: UINavigationController, items: [DropdownItem], selectedRow: Int = 0) {
        self.navigationController = navigationController
        self.sections = [DropdownSection(sectionIdentifier: "", items: items)]
        self.selectedIndexPath = [IndexPath(row: selectedRow, section: 0)]
        
        super.init(frame: CGRect.zero)
        
        clipsToBounds = true
        setupGestureView()
        initTableView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateForOrientationChange(_:)), name: UIApplication.willChangeStatusBarOrientationNotification, object: nil)
    }
    
    public init(navigationController: UINavigationController, sections: [DropdownSection], selectedIndexPath: [IndexPath], dispalySectionHeader: Bool = true, sectionHeaderStyle: SectionHeaderStyle = SectionHeaderStyle()) {
        self.navigationController = navigationController
        self.sections = sections
        self.selectedIndexPath = selectedIndexPath
        self.displaySectionHeader = dispalySectionHeader
        
        super.init(frame: CGRect.zero)
        
        clipsToBounds = true
        setupGestureView()
        initTableView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateForOrientationChange(_:)), name: UIApplication.willChangeStatusBarOrientationNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func updateForOrientationChange(_ nofication: Notification) {
        
        print("UIApplicationWillChangeStatusBarOrientation")
        
        self.hideMenu()
        
        /*
        var insetTop: CGFloat = 0
        if #available(iOS 11.0, *) {
            insetTop = UIApplication.shared.keyWindow!.safeAreaInsets.top
        }
        
        if let _ = (nofication as NSNotification).userInfo?[UIApplication.statusBarOrientationUserInfoKey] as? Int {
            var topOffset = navigationController.navigationBar.frame.height + insetTop
            /*
            var topOffset: CGFloat = 0
            switch oriention {
            case UIInterfaceOrientation.landscapeLeft.rawValue, UIInterfaceOrientation.landscapeRight.rawValue:
                if UIDevice.current.userInterfaceIdiom == .phone {
                    topOffset = navigationController.navigationBar.frame.height + insetTop
                } else {
                    topOffset = navigationController.navigationBar.frame.height + insetTop
                }
                
            case UIInterfaceOrientation.portrait.rawValue, UIInterfaceOrientation.portraitUpsideDown.rawValue:
                topOffset = navigationController.navigationBar.frame.height + insetTop
            
            default:
                break
            }
            */
            topOffset = topOffset + topOffsetY
            topConstraint?.constant = topOffset
            navigationBarCoverViewHeightConstraint?.constant = topOffset
            UIView.animate(withDuration: 0.1, animations: {
                self.windowRootView?.layoutIfNeeded()
            })
        }
        */
    }
    
    fileprivate func setupGestureView() {
        let gestureView = UIView()
        gestureView.backgroundColor = UIColor.clear
        addSubview(gestureView)
        gestureView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: gestureView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: gestureView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: gestureView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: gestureView, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0)])
        
        gestureView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hideMenu)))
    }
    
    fileprivate func initTableView() {
        tableView = UITableView(frame: CGRect.zero, style: .grouped)
        tableView.separatorStyle = separatorStyle
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedSectionFooterHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        addSubview(tableView)
    }
    
    fileprivate func layoutTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false

        tableViewHeight = tableviewHeight()
        
        let maxHeight = navigationController.view.frame.height - topLayoutConstraintConstant - defaultBottonMargin
        
        if tableViewHeight > maxHeight {
            if displaySectionHeader {
                tableViewHeight = maxHeight
            } else {
                tableViewHeight = round(maxHeight / rowHeight) * rowHeight
            }
        }
        
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: tableView as Any, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant:0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: tableView as Any, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: tableViewHeight)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: tableView as Any, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: tableView as Any, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0)])
    }
    
    fileprivate func setupTopSeperatorView() {
        let seperatorView = UIView()
        seperatorView.backgroundColor = tableViewSeperatorColor
        addSubview(seperatorView)
        seperatorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: seperatorView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: seperatorView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: seperatorView, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: seperatorView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0.5)])
    }
    
    fileprivate func setupNavigationBarCoverView(on view: UIView) {
        barCoverView = UIView()
        barCoverView?.backgroundColor = UIColor.clear
        view.addSubview(barCoverView!)
        barCoverView?.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: barCoverView!, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 0)])
        navigationBarCoverViewHeightConstraint = NSLayoutConstraint.init(item: barCoverView!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: topLayoutConstraintConstant)
        NSLayoutConstraint.activate([navigationBarCoverViewHeightConstraint!])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: barCoverView!, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: barCoverView!, attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1.0, constant: 0)])
        barCoverView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hideMenu)))
    }
    
    fileprivate func tableviewHeight() -> CGFloat {
        var height: CGFloat = 0
        if displaySectionHeader {
            height += sectionHeaderHeight * CGFloat(sections.count)
        }
        for section in sections {
            height += CGFloat(section.items.count) * rowHeight
        }
        return height
    }
    
    open func showMenu(isOnNavigaitionView: Bool = false) {
        delegate?.dropdownMenuWillShow(self)
        if isShow {
            hideMenu()
            return
        }
        
        isShow = true
        
        layoutTableView()
        setupTopSeperatorView()
        
        addedWindow = UIWindow(frame: self.navigationController.view.bounds)
        addedWindow?.rootViewController = UIViewController()
        addedWindow?.isHidden = false
        addedWindow?.makeKeyAndVisible()
        windowRootView = addedWindow!

        if displayNavigationBarCoverView {
            setupNavigationBarCoverView(on: windowRootView!)
        }
        
        windowRootView?.addSubview(self)
        
        translatesAutoresizingMaskIntoConstraints = false
        topConstraint = NSLayoutConstraint.init(item: self, attribute: .top, relatedBy: .equal, toItem: windowRootView, attribute: .top, multiplier: 1.0, constant: topLayoutConstraintConstant)
        NSLayoutConstraint.activate([topConstraint!])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: self, attribute: .bottom, relatedBy: .equal, toItem: windowRootView, attribute: .bottom, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: self, attribute: .left, relatedBy: .equal, toItem: windowRootView, attribute: .left, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: self, attribute: .right, relatedBy: .equal, toItem: windowRootView, attribute: .right, multiplier: 1.0, constant: 0)])
        
        backgroundColor = backgroudBeginColor
        self.tableView.frame.origin.y = -self.tableViewHeight
        UIView.animate(withDuration: animateDuration, delay: 0, options: UIView.AnimationOptions(rawValue: 7<<16), animations: {
            self.backgroundColor = self.backgroudEndColor
            self.tableView.frame.origin.y = 0
        }, completion: nil)
    }
    
    @objc open func hideMenu(isSelectAction: Bool = false) {
        delegate?.dropdownMenuWillDismiss(self)
        UIView.animate(withDuration: animateDuration, animations: {
            self.backgroundColor = self.backgroudBeginColor
            self.tableView.frame.origin.y = -self.tableViewHeight
        }, completion: { (finished) in
            if !isSelectAction {
                self.delegate?.dropdownMenuCancel(self)
            }
            self.barCoverView?.removeFromSuperview()
            self.removeFromSuperview()
            self.isShow = false
            
            if let _ = self.addedWindow {
                self.addedWindow?.isHidden = true
                UIApplication.shared.keyWindow?.makeKey()
            }
        })
    }
}

extension DropdownMenu: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        delegate?.dropdownMenu(self, willDisplay: cell, forRowAt: indexPath)
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let customCell = delegate?.dropdownMenu(self, cellForRowAt: indexPath) {
            return customCell
        }
        
        let item = sections[indexPath.section].items[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: "dropdownMenuCell")
        
        switch item.style {
        case .default:
            cell.textLabel?.textColor = textColor
            if let image = item.image {
                cell.imageView?.image = image
            }
        case .highlight:
            cell.textLabel?.textColor = highlightColor
            if let image = item.image {
                let highlightImage = image.withRenderingMode(.alwaysTemplate)
                cell.imageView?.image = highlightImage
                cell.imageView?.tintColor = highlightColor
            }
        }
        
        cell.textLabel?.text = item.title
        cell.textLabel?.font = textFont
        cell.tintColor = highlightColor
        cell.backgroundColor = cellBackgroundColor
        
        if displaySelected && selectedIndexPath.contains(indexPath) {   //indexPath == selectedIndexPath {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        if let accesoryImage = item.accessoryImage {
            cell.accessoryView = UIImageView(image: accesoryImage)
        }
        
        if zeroInsetSeperatorIndexPaths.contains(indexPath) {
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        } else {
            cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.layoutMargins.left, bottom: 0, right: 0)
        }
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return displaySectionHeader ? sections[section].sectionIdentifier : nil
    }
}

extension DropdownMenu: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return rowHeight
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return displaySectionHeader ? sectionHeaderHeight : CGFloat.leastNormalMagnitude
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        /*
        let shouldUpdateSelection = delegate?.dropdownMenu(self, shouldUpdateSelectionAt: indexPath) ?? true
        
        if displaySelected && shouldUpdateSelection {
            let item = sections[indexPath.section].items[indexPath.row]
            if item.accessoryImage  == nil {
                let previousSelectedcell = tableView.cellForRow(at: selectedIndexPath)
                previousSelectedcell?.accessoryType = .none
                selectedIndexPath = indexPath
                let cell = tableView.cellForRow(at: indexPath)
                cell?.accessoryType = .checkmark
            }
        }
        */
        tableView.deselectRow(at: indexPath, animated: true)
        hideMenu(isSelectAction: true)
        delegate?.dropdownMenu(self, didSelectRowAt: indexPath)
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionHeader = SectionHeader(style: sectionHeaderStyle)
        sectionHeader.titleLabel.text = sections[section].sectionIdentifier
        return sectionHeader
    }
}
