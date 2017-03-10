//
//  SwiftWebVCActivityChrome.swift
//
//  Created by Myles Ringle on 24/06/2015.
//  Transcribed from code used in SVWebViewController.
//  Copyright (c) 2015 Myles Ringle & Sam Vermette. All rights reserved.
//

import UIKit

class SwiftWebVCActivityChrome : SwiftWebVCActivity {

    override var activityTitle : String {
        return NSLocalizedString("Open in Chrome", tableName: "SwiftWebVC", comment: "")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for activityItem in activityItems {
            if activityItem is URL, UIApplication.shared.canOpenURL(URL(string: "googlechrome://")!) {
                return true;
            }
        }
        return false;
    }
    
    override func perform() {
        let inputURL: URL! = URLToOpen as URL!
        let scheme: String! = inputURL.scheme
        
        // Replace the URL Scheme with the Chrome equivalent.
        var chromeScheme: String? = nil;
        if scheme == "http" {
            chromeScheme = "googlechrome"
        }
        else if scheme == "https" {
            chromeScheme = "googlechromes"
        }
        
        // Proceed only if a valid Google Chrome URI Scheme is available.
        if chromeScheme != nil {
            let absoluteString: NSString! = inputURL!.absoluteString as NSString!
            let rangeForScheme: NSRange! = absoluteString.range(of: ":")
            let urlNoScheme: String! = absoluteString.substring(from: rangeForScheme.location)
            let chromeURLString: String! = chromeScheme!+urlNoScheme
            let chromeURL: URL! = URL(string: chromeURLString)
            
            // Open the URL with Chrome.
            UIApplication.shared.openURL(chromeURL)
        }
    }
    
}
