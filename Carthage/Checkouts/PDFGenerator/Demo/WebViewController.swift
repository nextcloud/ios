//
//  WebViewController.swift
//  PDFGenerator
//
//  Created by Suguru Kishimoto on 2016/03/23.
//
//

import UIKit
import WebKit
import PDFGenerator

class WebViewController: UIViewController {

    @IBOutlet fileprivate weak var webView: UIWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let req = NSMutableURLRequest(url: URL(string: "http://www.yahoo.co.jp")!, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 60)
        webView.loadRequest(req as URLRequest)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func generatePDF() {
        do {
            let dst = NSHomeDirectory() + "/sample_tblview.pdf"
            try PDFGenerator.generate(webView, to: dst)
            openPDFViewer(dst)
        } catch let error {
            print(error)
        }
        
    }

    fileprivate func openPDFViewer(_ pdfPath: String) {
        let url = URL(fileURLWithPath: pdfPath)
        let storyboard = UIStoryboard(name: "PDFPreviewVC", bundle: nil)
        let vc = storyboard.instantiateInitialViewController() as! PDFPreviewVC
        vc.setupWithURL(url)
        present(vc, animated: true, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
