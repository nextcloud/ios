//
//  NCViewerDocumentWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/09/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

class NCViewerDocumentWeb: NSObject {
    
    @objc static let sharedInstance: NCViewerDocumentWeb = {
        let instance = NCViewerDocumentWeb()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc func viewDocumentWebAt(_ metadata: tableMetadata, detail: CCDetail, width: Int, height: Int) {
        
        if !CCUtility.fileProviderStorageExists(metadata.fileID, fileNameView: metadata.fileNameView) {
            detail.navigationController?.popViewController(animated: true)
            return
        }
        
        let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
        let fileNameExtension = (metadata.fileNameView as NSString).pathExtension.uppercased()

        do {
            try FileManager.default.removeItem(atPath:fileNamePath)
        } catch { }
        
        do {
            try FileManager.default.linkItem(atPath: CCUtility.getDirectoryProviderStorageFileID(metadata.fileID, fileNameView: metadata.fileNameView), toPath: fileNamePath)
        } catch {
            print("error")
            return
        }
        
        let url = URL.init(fileURLWithPath: fileNamePath)

        let preferences = WKPreferences()
        let configuration = WKWebViewConfiguration()

        preferences.javaScriptEnabled = true
        configuration.preferences = preferences
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: height), configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        webView.isOpaque = false
        
        if fileNameExtension == "CSS" || fileNameExtension == "PY" || fileNameExtension == "XML" || fileNameExtension == "JS" {
            
            do {
                let dataFile = try String(contentsOf: url, encoding: String.Encoding(rawValue: String.Encoding.ascii.rawValue))
                
                if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.phone {
                    webView.loadHTMLString("<div style='font-size:40;font-family:Sans-Serif;'><pre>" + dataFile, baseURL: nil)
                } else {
                    webView.loadHTMLString("<div style='font-size:20;font-family:Sans-Serif;'><pre>" + dataFile, baseURL: nil)
                }
                
            } catch {
                print("error")
            }
            
        } else if CCUtility.isDocumentModifiableExtension(fileNameExtension) {
            
            let session = URLSession(configuration: URLSessionConfiguration.default)
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            
            let task = session.dataTask(with: request) { (data, response, error) in
                
                guard let data = data else {
                    return
                }
                guard let response = response else {
                    return
                }
                
                DispatchQueue.main.async {
                    
                    guard let encodingName = NCUchardet.sharedNUCharDet()?.encodingStringDetect(with: data) else {
                        return
                    }
                    webView.load(data, mimeType: response.mimeType!, characterEncodingName: encodingName, baseURL: url)
                }
            }
            
            task.resume()
            
        } else {
            
            webView.load(URLRequest(url: url))
        }
        
        detail.view.addSubview(webView)
    }
    
    func createToolbar(detail: CCDetail) {

        var safeAreaBottom: CGFloat = 0
        
        guard let rootView = UIApplication.shared.keyWindow else {
            return
        }
        if #available(iOS 11.0, *) {
            safeAreaBottom = rootView.safeAreaInsets.bottom
        }
        
        guard let detailView = detail.view else {
            return
        }

        let toolbar = UITabBar(frame: CGRect(x: 0 as CGFloat, y: detailView.bounds.size.height - CGFloat(k_detail_Toolbar_Height) - safeAreaBottom, width: detailView.bounds.size.width, height: CGFloat(k_detail_Toolbar_Height)))
        
        let flexible = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: detail, action: nil)
        let fixedSpaceMini = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: detail, action: nil)
        fixedSpaceMini.width = 25
        
       
        
        
    }
    
    
    /*
 - (void)createToolbar
 {
 CGFloat safeAreaBottom = 0;
 NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadataDetail.directoryID];
 if (!serverUrl)
 return;
 
 if (@available(iOS 11, *)) {
 safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
 }
 
 self.toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - TOOLBAR_HEIGHT - safeAreaBottom, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
 
 UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
 UIBarButtonItem *fixedSpaceMini = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
 fixedSpaceMini.width = 25;
 
 buttonModifyTxt = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"actionSheetModify"] style:UIBarButtonItemStylePlain target:self action:@selector(modifyTxtButtonPressed:)];
 if (![NCBrandOptions sharedInstance].disable_openin_file) {
 self.buttonAction = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"openFile"] style:UIBarButtonItemStylePlain target:self action:@selector(actionButtonPressed:)];
 }
 buttonShare  = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"share"] style:UIBarButtonItemStylePlain target:self action:@selector(shareButtonPressed:)];
 buttonDelete = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteButtonPressed:)];
 
 if ([CCUtility isDocumentModifiableExtension:fileNameExtension]) {
 if ([CCUtility isFolderEncrypted:serverUrl account:appDelegate.activeAccount]) // E2EE
 [self.toolbar setItems:[NSArray arrayWithObjects: buttonModifyTxt, flexible, buttonDelete, fixedSpaceMini, self.buttonAction,  nil]];
 else
 [self.toolbar setItems:[NSArray arrayWithObjects: buttonModifyTxt, flexible, buttonDelete, fixedSpaceMini, buttonShare, fixedSpaceMini, self.buttonAction,  nil]];
 } else {
 if ([CCUtility isFolderEncrypted:serverUrl account:appDelegate.activeAccount]) // E2EE
 [self.toolbar setItems:[NSArray arrayWithObjects: flexible, buttonDelete, fixedSpaceMini, self.buttonAction,  nil]];
 else
 [self.toolbar setItems:[NSArray arrayWithObjects: flexible, buttonDelete, fixedSpaceMini, buttonShare, fixedSpaceMini, self.buttonAction,  nil]];
 }
 
 [self.toolbar setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
 
 self.toolbar.barTintColor = [NCBrandColor sharedInstance].tabBar;
 self.toolbar.tintColor = [NCBrandColor sharedInstance].brandElement;
 
 [self.view addSubview:self.toolbar];
 }
 */
}
