//
//  SwiftModalWebVC.swift
//
//  Created by Myles Ringle on 24/06/2015.
//  Transcribed from code used in SVWebViewController.
//  Copyright (c) 2015 Myles Ringle & Oliver Letterer. All rights reserved.
//

import UIKit

@objc public protocol SwiftModalWebVCDelegate: class {
    @objc func didStartLoading()
    @objc func didReceiveServerRedirectForProvisionalNavigation(url: URL)
    @objc func didFinishLoading(success: Bool, url: URL)
    @objc func webDismiss()
}

public class SwiftModalWebVC: UINavigationController {
    
    @objc public weak var delegateWeb: SwiftModalWebVCDelegate?
    
    weak var webViewDelegate: UIWebViewDelegate? = nil
    
    @objc public convenience init(urlString: String, colorText: UIColor, colorDoneButton: UIColor, doneButtonVisible: Bool, hideToolbar: Bool = false) {
        let url = URL(string: urlString)!
        self.init(request: URLRequest(url: url), colorText: colorText, colorDoneButton: colorDoneButton, doneButtonVisible: doneButtonVisible, hideToolbar: hideToolbar)
    }
    
    public init(request: URLRequest, colorText: UIColor = UIColor.white, colorDoneButton: UIColor = UIColor.black, doneButtonVisible: Bool = false, hideToolbar: Bool = false) {
        
        let webViewController = SwiftWebVC(aRequest: request, hideToolbar: hideToolbar)
        webViewController.storedStatusColor = UINavigationBar.appearance().barStyle
        
        super.init(rootViewController: webViewController)

        let doneButton = UIBarButtonItem(image: SwiftWebVC.bundledImage(named: "SwiftWebVCDismiss"), style: UIBarButtonItem.Style.plain, target: webViewController, action: #selector(SwiftWebVC.doneButtonTapped))
    
        doneButton.tintColor = colorDoneButton
        webViewController.buttonColor = colorText
        webViewController.titleColor = colorText
        webViewController.view.backgroundColor = UIColor.clear
        
        UINavigationBar.appearance().barStyle = UIBarStyle.default
        
        if (doneButtonVisible == true) {
            if (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad) {
                webViewController.navigationItem.leftBarButtonItem = doneButton
            }
            else {
                webViewController.navigationItem.rightBarButtonItem = doneButton
            }
        }
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
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
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
        //print("Finished loading. Success: \(success).")
    }
    
    public func didFinishLoading(success: Bool, url: URL) {
        self.delegateWeb?.didFinishLoading(success: success, url: url)
    }
    
    public func webDismiss() {
        self.delegateWeb?.webDismiss()
    }
}
