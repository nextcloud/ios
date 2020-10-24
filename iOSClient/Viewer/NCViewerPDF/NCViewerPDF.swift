//
//  NCViewerPDF.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/02/2020.
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
import PDFKit

class NCViewerPDF: UIViewController, NCViewerPDFSearchDelegate {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadata = tableMetadata()
    
    private var pdfView = PDFView()
    private var thumbnailViewHeight: CGFloat = 40
    private var pdfThumbnailView = PDFThumbnailView()
    private var pdfDocument: PDFDocument?
    private let pageView = UIView()
    private let pageViewLabel = UILabel()
    private var pageViewWidthAnchor : NSLayoutConstraint?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
          
        let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: k_notificationCenter_menuDetailClose), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(searchText), name: NSNotification.Name(rawValue: k_notificationCenter_menuSearchTextPDF), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePageChange), name: Notification.Name.PDFViewPageChanged, object: nil)
       
        changeTheming()

        pdfView = PDFView.init(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        pdfDocument = PDFDocument(url: URL(fileURLWithPath: filePath))
        
        pdfView.document = pdfDocument
        pdfView.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.displayDirection = .horizontal
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleBottomMargin]
        pdfView.usePageViewController(true, withViewOptions: nil)
        
        view.addSubview(pdfView)
        
        pdfThumbnailView.translatesAutoresizingMaskIntoConstraints = false
        pdfThumbnailView.pdfView = pdfView
        pdfThumbnailView.layoutMode = .horizontal
        pdfThumbnailView.thumbnailSize = CGSize(width: 40, height: thumbnailViewHeight)
        pdfThumbnailView.backgroundColor = .clear
        //pdfThumbnailView.layer.shadowOffset.height = -5
        //pdfThumbnailView.layer.shadowOpacity = 0.25
        
        view.addSubview(pdfThumbnailView)
        
        pdfThumbnailView.heightAnchor.constraint(equalToConstant: thumbnailViewHeight).isActive = true
        pdfThumbnailView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        pdfThumbnailView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        pdfThumbnailView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        
        pageView.translatesAutoresizingMaskIntoConstraints = false
        pageView.layer.cornerRadius = 10
        pageView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        
        view.addSubview(pageView)
        
        pageView.heightAnchor.constraint(equalToConstant: 30).isActive = true
        pageViewWidthAnchor = pageView.widthAnchor.constraint(equalToConstant: 10)
        pageViewWidthAnchor?.isActive = true
        pageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4).isActive = true
        pageView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 7).isActive = true
        
        pageViewLabel.translatesAutoresizingMaskIntoConstraints = false
        pageViewLabel.textAlignment = .center
        pageViewLabel.textColor = .gray
        
        pageView.addSubview(pageViewLabel)
        
        pageViewLabel.leftAnchor.constraint(equalTo: pageView.leftAnchor).isActive = true
        pageViewLabel.rightAnchor.constraint(equalTo: pageView.rightAnchor).isActive = true
        pageViewLabel.topAnchor.constraint(equalTo: pageView.topAnchor).isActive = true
        pageViewLabel.bottomAnchor.constraint(equalTo: pageView.bottomAnchor).isActive = true
        
        pdfView.layoutIfNeeded()
        handlePageChange()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(tapGesture)
        
        // recognize single / double tap
        for gesture in pdfView.gestureRecognizers! {
            tapGesture.require(toFail:gesture)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let buttonMore = UIBarButtonItem.init(image: CCGraphics.changeThemingColorImage(UIImage(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView), style: .plain, target: self, action: #selector(self.openMenuMore))
        navigationItem.rightBarButtonItem = buttonMore
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.title = metadata.fileNameView

        appDelegate.activeViewController = self
    }
    
    @objc func viewUnload() {
        
        navigationController?.popViewController(animated: true)
    }
    
    //MARK: - NotificationCenter
   
    @objc func moveFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataNew = userInfo["metadataNew"] as? tableMetadata {
                if metadata.ocId == self.metadata.ocId {
                    self.metadata = metadataNew
                }
            }
        }
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.ocId == self.metadata.ocId {
                    viewUnload()
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.ocId == self.metadata.ocId {
                    self.metadata = metadata
                    navigationItem.title = metadata.fileNameView
                }
            }
        }
    }

    @objc func changeTheming() {
        
        if navigationController?.isNavigationBarHidden == false {
            pdfView.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        }
    }
    
    @objc func handlePageChange() {
        
        guard let curPage = pdfView.currentPage?.pageRef?.pageNumber else { pageView.alpha = 0; return }
        guard let totalPages = pdfView.document?.pageCount else { return }
        
        pageView.alpha = 1
        pageViewLabel.text = String(curPage) + " " + NSLocalizedString("_of_", comment: "") + " " + String(totalPages)
        pageViewWidthAnchor?.constant = pageViewLabel.intrinsicContentSize.width + 10
        
        UIView.animate(withDuration: 1.0, delay: 3.0, animations: {
            self.pageView.alpha = 0
        })
    }
    
    //MARK: - Action
    
    @objc func openMenuMore() {
        NCViewer.shared.toggleMoreMenu(viewController: self, metadata: metadata)
    }
    
    //MARK: - Gesture Recognizer
    
    @objc func didTap(_ recognizer: UITapGestureRecognizer) {
        
        if navigationController?.isNavigationBarHidden ?? false {
            
            navigationController?.setNavigationBarHidden(false, animated: false)
            pdfThumbnailView.isHidden = false
            pdfView.backgroundColor = NCBrandColor.sharedInstance.backgroundView

        } else {
            
            let point = recognizer.location(in: pdfView)
            if point.y > pdfView.frame.height - thumbnailViewHeight { return }
            
            navigationController?.setNavigationBarHidden(true, animated: false)
            pdfThumbnailView.isHidden = true
            pdfView.backgroundColor = .black
        }

        handlePageChange()
    }
    
    //MARK: - Search
    
    @objc func searchText() {
        
        let viewerPDFSearch = UIStoryboard.init(name: "NCViewerPDF", bundle: nil).instantiateViewController(withIdentifier: "NCViewerPDFSearch") as! NCViewerPDFSearch
        viewerPDFSearch.delegate = self
        viewerPDFSearch.pdfDocument = pdfDocument
        
        let navigaionController = UINavigationController.init(rootViewController: viewerPDFSearch)
        self.present(navigaionController, animated: true)
    }
    
    func searchPdfSelection(_ pdfSelection: PDFSelection) {
        pdfSelection.color = .yellow
        pdfView.currentSelection = pdfSelection
        pdfView.go(to: pdfSelection)
    }
}

extension NCViewerPDF : UINavigationControllerDelegate {

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
     }
}
