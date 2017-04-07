//
//  SwiftModalWebVC.swift
//
//  Created by Myles Ringle on 24/06/2015.
//  Transcribed from code used in SVWebViewController.
//  Copyright (c) 2015 Myles Ringle & Oliver Letterer. All rights reserved.
//

import UIKit

public protocol SwiftModalWebVCDelegate: class {
    func didStartLoading()
    func didReceiveServerRedirectForProvisionalNavigation(url: URL)
    func didFinishLoading(success: Bool, url: URL)
}

public class SwiftModalWebVC: UINavigationController {
    
    public weak var delegateWeb: SwiftModalWebVCDelegate?
    
    public enum SwiftModalWebVCTheme {
        case lightBlue, lightBlack, dark, customLoginWeb
    }
    
    weak var webViewDelegate: UIWebViewDelegate? = nil
    
    public convenience init(urlString: String) {
        self.init(pageURL: URL(string: urlString)!)
    }
    
    public convenience init(urlString: String, theme: SwiftModalWebVCTheme) {
        self.init(pageURL: URL(string: urlString)!, theme: theme)
    }
    
    public convenience init(urlString: String, theme: SwiftModalWebVCTheme, color : UIColor) {
        self.init(pageURL: URL(string: urlString)!, theme: theme, color: color)
    }
    
    public convenience init(pageURL: URL) {
        self.init(request: URLRequest(url: pageURL))
    }
    
    public convenience init(pageURL: URL, theme: SwiftModalWebVCTheme) {
        self.init(request: URLRequest(url: pageURL), theme: theme)
    }
   
    public convenience init(pageURL: URL, theme: SwiftModalWebVCTheme, color : UIColor) {
        self.init(request: URLRequest(url: pageURL), theme: theme, color: color)
    }
    
    public init(request: URLRequest, theme: SwiftModalWebVCTheme = .dark, color : UIColor = UIColor.clear) {
        
        let webViewController = SwiftWebVC(aRequest: request)
        webViewController.storedStatusColor = UINavigationBar.appearance().barStyle
        
        let doneButton = UIBarButtonItem(image: SwiftWebVC.bundledImage(named: "SwiftWebVCDismiss"),
                                         style: UIBarButtonItemStyle.plain,
                                         target: webViewController,
                                         action: #selector(SwiftWebVC.doneButtonTapped))
        
        switch theme {
        case .lightBlue:
            doneButton.tintColor = nil
            webViewController.buttonColor = nil
            webViewController.titleColor = UIColor.black
            UINavigationBar.appearance().barStyle = UIBarStyle.default
        case .lightBlack:
            doneButton.tintColor = UIColor.darkGray
            webViewController.buttonColor = UIColor.darkGray
            webViewController.titleColor = UIColor.black
            UINavigationBar.appearance().barStyle = UIBarStyle.default
        case .dark:
            doneButton.tintColor = UIColor.white
            webViewController.buttonColor = UIColor.white
            webViewController.titleColor = UIColor.groupTableViewBackground
            UINavigationBar.appearance().barStyle = UIBarStyle.black
        case .customLoginWeb:
            webViewController.buttonColor = UIColor.white
            UINavigationBar.appearance().barStyle = UIBarStyle.default
            UINavigationBar.appearance().tintColor = color
        }
        
        if (theme != .customLoginWeb) {
            if (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad) {
                webViewController.navigationItem.leftBarButtonItem = doneButton
            }
            else {
                webViewController.navigationItem.rightBarButtonItem = doneButton
            }
        }
        
        super.init(rootViewController: webViewController)
        webViewController.delegate = self
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
    }
}

extension SwiftModalWebVC: SwiftWebVCDelegate {
    
    public func didStartLoading() {
        self.delegateWeb?.didStartLoading()
    }
    
    public func didReceiveServerRedirectForProvisionalNavigation(url: URL) {
        self.delegateWeb?.didReceiveServerRedirectForProvisionalNavigation(url: url)
    }
    
    public func didFinishLoading(success: Bool) {
        print("Finished loading. Success: \(success).")
    }
    
    public func didFinishLoading(success: Bool, url: URL) {
        self.delegateWeb?.didFinishLoading(success: success, url: url)
    }
}
