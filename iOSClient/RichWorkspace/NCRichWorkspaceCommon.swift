//
//  NCRichWorkspaceCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/01/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
import NCCommunication
import SwiftRichString

@objc class NCRichWorkspaceCommon: NSObject {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @objc func createViewerNextcloudText(serverUrl: String,viewController: UIViewController) {
        
        if !appDelegate.reachability.isReachable() {
            
            NCContentPresenter.shared.messageNotification("_error_", description: "_go_online_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: 0)
            return;
        }
        
        NCUtility.sharedInstance.startActivityIndicator(view: viewController.view, bottom: 0)
        
        let fileNamePath = CCUtility.returnFileNamePath(fromFileName: k_fileNameRichWorkspace, serverUrl: serverUrl, activeUrl: appDelegate.activeUrl)!
        NCCommunication.sharedInstance.NCTextCreateFile(urlString: appDelegate.activeUrl, fileNamePath: fileNamePath, editor: "text", templateId: "", account: appDelegate.activeAccount) { (account, url, errorCode, errorMessage) in
            
            NCUtility.sharedInstance.stopActivityIndicator()
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                
                if let viewerRichWorkspaceWebView = UIStoryboard.init(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerRichWorkspaceWebView") as? NCViewerRichWorkspaceWebView {
                    
                    viewerRichWorkspaceWebView.url = url!
                    viewerRichWorkspaceWebView.presentationController?.delegate = viewController as? UIAdaptivePresentationControllerDelegate
                    
                    viewController.present(viewerRichWorkspaceWebView, animated: true, completion: nil)
                }
                
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: errorCode)
            }
        }
    }
    
    @objc func openViewerNextcloudText(serverUrl: String, viewController: UIViewController) {
        
        if !appDelegate.reachability.isReachable() {
            
            NCContentPresenter.shared.messageNotification("_error_", description: "_go_online_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: 0)
            return;
        }
        
        if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", appDelegate.activeAccount, serverUrl, k_fileNameRichWorkspace.lowercased())) {
            
            if metadata.url == "" {
                
                NCUtility.sharedInstance.startActivityIndicator(view: viewController.view, bottom: 0)
                
                let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: appDelegate.activeUrl)!
                NCCommunication.sharedInstance.NCTextOpenFile(urlString: appDelegate.activeUrl, fileNamePath: fileNamePath, editor: "text", account: appDelegate.activeAccount) { (account, url, errorCode, errorMessage) in
                    
                    NCUtility.sharedInstance.stopActivityIndicator()
                    
                    if errorCode == 0 && account == self.appDelegate.activeAccount {
                        
                        if let viewerRichWorkspaceWebView = UIStoryboard.init(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerRichWorkspaceWebView") as? NCViewerRichWorkspaceWebView {
                            
                            viewerRichWorkspaceWebView.url = url!
                            viewerRichWorkspaceWebView.metadata = metadata
                            viewerRichWorkspaceWebView.presentationController?.delegate = viewController as? UIAdaptivePresentationControllerDelegate
                            
                            viewController.present(viewerRichWorkspaceWebView, animated: true, completion: nil)
                        }
                        
                    } else if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: errorCode)
                    }
                }
                
            } else {
                
                if let viewerRichWorkspaceWebView = UIStoryboard.init(name: "NCViewerRichWorkspace", bundle: nil).instantiateViewController(withIdentifier: "NCViewerRichWorkspaceWebView") as? NCViewerRichWorkspaceWebView {
                    
                    viewerRichWorkspaceWebView.url = metadata.url
                    viewerRichWorkspaceWebView.metadata = metadata
                    viewerRichWorkspaceWebView.presentationController?.delegate = viewController as? UIAdaptivePresentationControllerDelegate
                    
                    viewController.present(viewerRichWorkspaceWebView, animated: true, completion: nil)
                }
            }
        }
    }
    
    @objc func setRichWorkspaceText(_ richWorkspace: String, userInteractionEnabled: Bool, textView: UITextView) {
           
           let h1 = Style {
               $0.font = UIFont.systemFont(ofSize: 25, weight: .bold)
               $0.color = NCBrandColor.sharedInstance.textView
           }
           let h2 = Style {
               $0.font = UIFont.systemFont(ofSize: 23, weight: .bold)
               $0.color = NCBrandColor.sharedInstance.textView
           }
           let h3 = Style {
               $0.font = UIFont.systemFont(ofSize: 21, weight: .bold)
               $0.color = NCBrandColor.sharedInstance.textView
           }
           let h4 = Style {
               $0.font = UIFont.systemFont(ofSize: 19, weight: .bold)
               $0.color = NCBrandColor.sharedInstance.textView
           }
           let h5 = Style {
               $0.font = UIFont.systemFont(ofSize: 17, weight: .bold)
               $0.color = NCBrandColor.sharedInstance.textView
           }
           let h6 = Style {
               $0.font = UIFont.systemFont(ofSize: 15, weight: .bold)
               $0.color = NCBrandColor.sharedInstance.textView
           }
           let normal = Style {
               $0.font = UIFont.systemFont(ofSize: 15)
               $0.color = NCBrandColor.sharedInstance.textView
           }
          
           var richWorkspaceStyling = ""
           let richWorkspaceArray = richWorkspace.components(separatedBy: "\n")
           for string in richWorkspaceArray {
               if string.hasPrefix("# ") {
                   richWorkspaceStyling = richWorkspaceStyling + "<h1>" + string.replacingOccurrences(of: "# ", with: "") + "</h1>\r\n"
               } else if string.hasPrefix("## ") {
                   richWorkspaceStyling = richWorkspaceStyling + "<h2>" + string.replacingOccurrences(of: "## ", with: "") + "</h2>\r\n"
               } else if string.hasPrefix("### ") {
                   richWorkspaceStyling = richWorkspaceStyling + "<h3>" + string.replacingOccurrences(of: "### ", with: "") + "</h3>\r\n"
               } else if string.hasPrefix("#### ") {
                   richWorkspaceStyling = richWorkspaceStyling + "<h4>" + string.replacingOccurrences(of: "#### ", with: "") + "</h4>\r\n"
               } else if string.hasPrefix("##### ") {
                   richWorkspaceStyling = richWorkspaceStyling + "<h5>" + string.replacingOccurrences(of: "##### ", with: "") + "</h5>\r\n"
               } else if string.hasPrefix("###### ") {
                   richWorkspaceStyling = richWorkspaceStyling + "<h6>" + string.replacingOccurrences(of: "###### ", with: "") + "</h6>\r\n"
               } else {
                   richWorkspaceStyling = richWorkspaceStyling + string + "\r\n"
               }
           }
           
           textView.attributedText = richWorkspaceStyling.set(style: StyleGroup(base: normal, ["h1": h1, "h2": h2, "h3": h3, "h4": h4, "h5": h5, "h6": h6]))
           textView.isUserInteractionEnabled = userInteractionEnabled
       }
}
