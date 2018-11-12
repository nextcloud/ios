//
//  PDFViewController.swift
//  PDFMaker
//
//  Created by Suguru Kishimoto on 2016/02/05.
//
//

import UIKit

class PDFViewController: UIViewController {
    
    @IBOutlet private weak var webView: UIWebView!
    @IBOutlet private weak var closeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func setupWithURL(url: NSURL) {
        let req = NSURLRequest(URL: url, cachePolicy: .ReloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 60)
        webView.loadRequest(req)
    }
    
}
