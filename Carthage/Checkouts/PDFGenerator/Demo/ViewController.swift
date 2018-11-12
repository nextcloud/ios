//
//  ViewController.swift
//  Demo
//
//  Created by Suguru Kishimoto on 2016/02/04.
//
//

import UIKit
import PDFGenerator

class ViewController: UIViewController {
    
    fileprivate var outputAsData: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    fileprivate func getImagePath(_ number: Int) -> String {
        return Bundle.main.path(forResource: "sample_\(number)", ofType: "jpg")!
    }
    
    fileprivate func getDestinationPath(_ number: Int) -> String {
        return NSHomeDirectory() + "/sample\(number).pdf"
    }
    
    @objc @IBAction fileprivate func generateSamplePDFFromViews(_ sender: AnyObject?) {
        let v1 = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let v2 = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
        let v3 = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
        v1.backgroundColor = UIColor.red
        v1.contentSize = CGSize(width: 100, height: 100)
        v2.backgroundColor = UIColor.green
        v3.backgroundColor = UIColor.blue
        
        do {
            let dst = getDestinationPath(1)
            if outputAsData {
                let data = try PDFGenerator.generated(by: [v1, v2, v3])
                try data.write(to: URL(fileURLWithPath: dst))
            } else {
                try PDFGenerator.generate([v1, v2, v3], to: dst)
            }
            openPDFViewer(dst)
        } catch (let e) {
            print(e)
        }
    }
    
    @objc @IBAction fileprivate func generateSamplePDFFromImages(_ sender: AnyObject?) {
        let dst = getDestinationPath(2)
        autoreleasepool {
            do {
                var images = [UIImage]()
                (0..<3).forEach {
                    images.append(UIImage(contentsOfFile: getImagePath($0))!)
                }
                if outputAsData {
                    let data = try PDFGenerator.generated(by: images)
                    try data.write(to: URL(fileURLWithPath: dst))
                } else {
                    try PDFGenerator.generate(images, to: dst, dpi: .custom(144), password: "123456")
                }
                openPDFViewer(dst)
            } catch (let e) {
                print(e)
            }
        }
    }
    
    @objc @IBAction fileprivate func generateSamplePDFFromImagePaths(_ sender: AnyObject?) {
        do {
            let dst = getDestinationPath(3)
            var imagePaths = [String]()
            (3..<6).forEach {
                imagePaths.append(getImagePath($0))
            }
            if outputAsData {
                let data = try PDFGenerator.generated(by: imagePaths)
                try data.write(to: URL(fileURLWithPath: dst))
            } else {
                try PDFGenerator.generate(imagePaths, to: dst)
            }
            openPDFViewer(dst)
        } catch (let e) {
            print(e)
        }
    }
    
    @objc @IBAction fileprivate func generateSamplePDFFromPages(_ sender: AnyObject?) {
        let v1 = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        v1.backgroundColor = UIColor.red
        let v2 = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
        v2.backgroundColor = UIColor.green
        
        let page1 = PDFPage.view(v1)
        let page2 = PDFPage.view(v2)
        let page3 = PDFPage.whitePage(CGSize(width: 200, height: 100))
        let page4 = PDFPage.image(UIImage(contentsOfFile: getImagePath(1))!)
        let page5 = PDFPage.imagePath(getImagePath(2))
        let pages = [page1, page2, page3, page4, page5]
        do {
            let dst = getDestinationPath(3)
            if outputAsData {
                let data = try PDFGenerator.generated(by: pages)
                try data.write(to: URL(fileURLWithPath: dst))
            } else {
                try PDFGenerator.generate(pages, to: dst)
            }
            openPDFViewer(dst)
        } catch (let e) {
            print(e)

        }
    }
    
    @objc @IBAction fileprivate func generatePDFFromStackedScrollView(_: AnyObject?) {
        let storyboard = UIStoryboard(name: "PDFOutput", bundle: nil)
        let vc = storyboard.instantiateInitialViewController()!
        
        present(vc, animated: true, completion: nil)
    }

    fileprivate func openPDFViewer(_ pdfPath: String) {
        let url = URL(fileURLWithPath: pdfPath)        
        let storyboard = UIStoryboard(name: "PDFPreviewVC", bundle: nil)
        let vc = storyboard.instantiateInitialViewController() as! PDFPreviewVC
        vc.setupWithURL(url)
        present(vc, animated: true, completion: nil)
    }

    @objc @IBAction fileprivate func goSampleTableView(_ sender: AnyObject?) {
        let storyboard = UIStoryboard(name: "SampleTableViewController", bundle: nil)
        let vc = storyboard.instantiateInitialViewController() as! SampleTableViewController
        present(vc, animated: true, completion: nil)
    }
    
    @objc @IBAction fileprivate func goSampleWebView(_ sender: AnyObject?) {
        let storyboard = UIStoryboard(name: "WebViewController", bundle: nil)
        let vc = storyboard.instantiateInitialViewController() as! WebViewController
        present(vc, animated: true, completion: nil)
    }

}
