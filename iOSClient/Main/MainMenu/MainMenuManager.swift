//
//  MainMenuManager.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 16.01.20.
//  Copyright © 2020 TWS. All rights reserved.
//

import FloatingPanel

@objc class MainMenuManager: NSObject {
    
    
    @objc public static let sharedInstance = MainMenuManager()
    
    private override init(){
    
    }
    
    @objc public func showMenuIn(viewController: UIViewController){
        let mainMenuViewController = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MainMenuTableViewController") as! MainMenuTableViewController
        
        let fpc = FloatingPanelController()
        fpc.surfaceView.grabberHandle.isHidden = true
        fpc.delegate = mainMenuViewController
        fpc.set(contentViewController: mainMenuViewController)
        fpc.track(scrollView: mainMenuViewController.tableView)
        fpc.isRemovalInteractionEnabled = true
        if #available(iOS 11, *) {
            fpc.surfaceView.cornerRadius = 16
        } else {
            fpc.surfaceView.cornerRadius = 0
        }

        viewController.present(fpc, animated: true, completion: nil)
    }
}
