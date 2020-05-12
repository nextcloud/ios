//
//  DropUpMenu.swift
//  DropUpMenu
//
//  Created by Suric on 16/8/11.
//  Copyright © 2016年 teambition. All rights reserved.
//

import UIKit

public protocol DropUpMenuDelegate: class {
    func dropUpMenu(_ dropUpMenu: DropUpMenu, cellForRowAt indexPath: IndexPath) -> UITableViewCell?
    func dropUpMenu(_ dropUpMenu: DropUpMenu, didSelectRowAt indexPath: IndexPath)
    func dropUpMenuCancel(_ dropUpMenu: DropUpMenu)
    func dropUpMenuWillDismiss(_ dropUpMenu: DropUpMenu)
    func dropUpMenuWillShow(_ dropUpMenu: DropUpMenu)
}

public extension DropUpMenuDelegate {
    func dropUpMenu(_ dropUpMenu: DropUpMenu, cellForRowAt indexPath: IndexPath) -> UITableViewCell? {
        return nil
    }
    
    func dropUpMenu(_ dropUpMenu: DropUpMenu, didSelectRowAt indexPath: IndexPath) { }
    
    func dropUpMenuCancel(_ dropUpMenu: DropUpMenu) { }
  
    func dropUpMenuWillDismiss(_ dropUpMenu: DropUpMenu) { }
  
    func dropUpMenuWillShow(_ dropUpMenu: DropUpMenu) { }
}

private let screenRect = UIScreen.main.bounds

open class DropUpMenu: UIView {
    fileprivate var items: [DropdownItem] = []
    fileprivate var selectedRow: Int
    open var tableView: UITableView!
    fileprivate var barCoverView: UIView!
    fileprivate var isShow = false
    fileprivate var addedWindow: UIWindow?
    fileprivate var windowRootView: UIView?
    fileprivate lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        return UITapGestureRecognizer(target: self, action: #selector(self.hideMenu))
    }()
    
    open weak var delegate: DropUpMenuDelegate?
    
    open var animateDuration: TimeInterval = 0.25
    
    open var backgroudBeginColor: UIColor = UIColor.black.withAlphaComponent(0)
    open var backgroudEndColor = UIColor(white: 0, alpha: 0.4)
    
    open var rowHeight: CGFloat = 50
    open var tableViewHeight: CGFloat = 0
    open var defaultBottonMargin: CGFloat = 150
    
    open var textColor: UIColor = UIColor(red: 56.0/255.0, green: 56.0/255.0, blue: 56.0/255.0, alpha: 1.0)
    open var highlightColor: UIColor = UIColor(red: 3.0/255.0, green: 169.0/255.0, blue: 244.0/255.0, alpha: 1.0)
    open var tableViewBackgroundColor: UIColor = UIColor(red: 242.0/255.0, green: 242.0/255.0, blue: 242.0/255.0, alpha: 1.0) {
        didSet {
            tableView.backgroundColor = tableViewBackgroundColor
        }
    }
    open var tableViewSeperatorColor = UIColor(red: 217.0/255.0, green: 217.0/255.0, blue: 217.0/255.0, alpha: 1.0) {
        didSet {
            tableView.separatorColor = tableViewSeperatorColor
        }
    }
    open var cellBackgroundColor = UIColor.white

    open var displaySelected: Bool = true
    open var bottomOffsetY: CGFloat = 0
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public init(items: [DropdownItem], selectedRow: Int = 0, bottomOffsetY: CGFloat = 0) {
        self.items = items
        self.selectedRow = selectedRow
        self.bottomOffsetY = bottomOffsetY
        
        let frame = CGRect(x: 0, y: 0, width: screenRect.width, height: screenRect.height - bottomOffsetY)
        super.init(frame: frame)
        
        clipsToBounds = true
        setupGestureView()
        initTableView()
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
        
        gestureView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    fileprivate func initTableView() {
        tableView = UITableView(frame: CGRect.zero, style: .grouped)
        tableView?.delegate = self
        tableView?.dataSource = self
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        addSubview(tableView)
    }
    
    fileprivate func layoutTableView() {
        tableViewHeight = CGFloat(items.count) * rowHeight
        let maxHeight = UIScreen.main.bounds.height - bottomOffsetY
        if tableViewHeight > maxHeight {
            tableViewHeight = maxHeight
        }
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: tableView as Any, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant:0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: tableView as Any, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: tableViewHeight)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: tableView as Any, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: tableView as Any, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0)])
    }
    
    fileprivate func setupBottomSeperatorView() {
        let seperatorView = UIView()
        seperatorView.backgroundColor = tableViewSeperatorColor
        addSubview(seperatorView)
        seperatorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: seperatorView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: seperatorView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: seperatorView, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: seperatorView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0.5)])
    }
    
    fileprivate func setupBottomCoverView(on view: UIView) {
        barCoverView = UIView()
        barCoverView.backgroundColor = UIColor.clear
        barCoverView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(barCoverView)
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: barCoverView as Any, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: barCoverView as Any, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: bottomOffsetY)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: barCoverView as Any, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: barCoverView as Any, attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1.0, constant: 0)])
        barCoverView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hideMenu)))
    }
    
    open func showMenu() {
        delegate?.dropUpMenuWillShow(self)
        if isShow {
            hideMenu()
            return
        }
        isShow = true
        
        layoutTableView()
        setupBottomSeperatorView()
        
        if let rootView = UIApplication.shared.keyWindow {
            windowRootView = rootView
        } else {
            addedWindow = UIWindow(frame: UIScreen.main.bounds)
            addedWindow?.rootViewController = UIViewController()
            addedWindow?.isHidden = false
            addedWindow?.makeKeyAndVisible()
            windowRootView = addedWindow!
        }
        setupBottomCoverView(on: windowRootView!)
        windowRootView?.addSubview(self)
        
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: self, attribute: .top, relatedBy: .equal, toItem: windowRootView, attribute: .top, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: self, attribute: .bottom, relatedBy: .equal, toItem: windowRootView, attribute: .bottom, multiplier: 1.0, constant: -bottomOffsetY)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: self, attribute: .left, relatedBy: .equal, toItem: windowRootView, attribute: .left, multiplier: 1.0, constant: 0)])
        NSLayoutConstraint.activate([NSLayoutConstraint.init(item: self, attribute: .right, relatedBy: .equal, toItem: windowRootView, attribute: .right, multiplier: 1.0, constant: 0)])
        
        backgroundColor = backgroudBeginColor
        self.tableView.frame.origin.y = screenRect.height - bottomOffsetY
        UIView.animate(withDuration: animateDuration, delay: 0, options: UIView.AnimationOptions(rawValue: 7<<16), animations: {
            self.backgroundColor = self.backgroudEndColor
            self.tableView.frame.origin.y = screenRect.height - self.bottomOffsetY - self.tableViewHeight
            }, completion: nil)
    }
    
    @objc open func hideMenu(isSelectAction: Bool = false) {
        delegate?.dropUpMenuWillDismiss(self)
        UIView.animate(withDuration: animateDuration, animations: {
            self.backgroundColor = self.backgroudBeginColor
            self.tableView.frame.origin.y = screenRect.height - self.bottomOffsetY
        }, completion: { (finished) in
            if !isSelectAction {
                self.delegate?.dropUpMenuCancel(self)
            }

            self.barCoverView.removeFromSuperview()
            self.removeFromSuperview()
            self.isShow = false
            
            if let _ = self.addedWindow {
                self.addedWindow?.isHidden = true
                UIApplication.shared.keyWindow?.makeKey()
            }
        }) 
    }
}

extension DropUpMenu: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let customCell = delegate?.dropUpMenu(self, cellForRowAt: indexPath) {
            return customCell
        }
        
        let item = items[(indexPath as NSIndexPath).row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: "dropUpMenuCell")
        
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
        cell.tintColor = highlightColor
        cell.backgroundColor = cellBackgroundColor
        
        if displaySelected && (indexPath as NSIndexPath).row == selectedRow {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        if let accesoryImage = item.accessoryImage {
            cell.accessoryView = UIImageView(image: accesoryImage)
        }
        
        return cell
    }
}

extension DropUpMenu: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return rowHeight
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNonzeroMagnitude
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if displaySelected {
            let item = items[(indexPath as NSIndexPath).row]
            if item.accessoryImage  == nil {
                let previousSelectedcell = tableView.cellForRow(at: IndexPath(row: selectedRow, section: 0))
                previousSelectedcell?.accessoryType = .none
                selectedRow = (indexPath as NSIndexPath).row
                let cell = tableView.cellForRow(at: indexPath)
                cell?.accessoryType = .checkmark
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
        hideMenu(isSelectAction: true)
        delegate?.dropUpMenu(self, didSelectRowAt: indexPath)
    }
}

