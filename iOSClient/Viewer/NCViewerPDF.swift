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

@available(iOS 11, *)

@objc class NCViewerPDF: PDFView {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var thumbnailViewHeight: CGFloat = 48
    private var pdfThumbnailView: PDFThumbnailView?
    private var backgroundView: UIView?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect) {
        let height = frame.height - frame.origin.y - thumbnailViewHeight
        super.init(frame: CGRect(x: 0, y: 0, width: frame.width, height: height))
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
    }
    
    @objc func changeTheming() {
        guard let navigationController = appDelegate.activeDetail.navigationController else { return }

        if navigationController.isNavigationBarHidden == false {
            backgroundColor = NCBrandColor.sharedInstance.backgroundView
        }
    }
    
    @objc func setupPdfView(filePath: URL, view: UIView) {
        self.backgroundView = view
        guard let pdfDocument = PDFDocument(url: filePath) else { return }
        
        document = pdfDocument
        backgroundColor = NCBrandColor.sharedInstance.backgroundView
        displayMode = .singlePageContinuous
        autoScales = true
        displayDirection = .horizontal
        autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleBottomMargin]
        usePageViewController(true, withViewOptions: nil)
        
        view.addSubview(self)
        
        pdfThumbnailView = PDFThumbnailView()
        pdfThumbnailView!.translatesAutoresizingMaskIntoConstraints = false
        pdfThumbnailView!.pdfView = self
        pdfThumbnailView!.layoutMode = .horizontal
        pdfThumbnailView!.thumbnailSize = CGSize(width: 40, height: thumbnailViewHeight - 2)
        //pdfThumbnailView.layer.shadowOffset.height = -5
        //pdfThumbnailView.layer.shadowOpacity = 0.25
        
        view.addSubview(pdfThumbnailView!)
        
        pdfThumbnailView!.heightAnchor.constraint(equalToConstant: thumbnailViewHeight).isActive = true
        pdfThumbnailView!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        pdfThumbnailView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        pdfThumbnailView!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func didTap(_ recognizer: UITapGestureRecognizer) {
        guard let navigationController = appDelegate.activeDetail.navigationController else { return }
        guard let backgroundView = self.backgroundView else { return }
        
        if navigationController.isNavigationBarHidden {
            
            navigationController.isNavigationBarHidden = false
            pdfThumbnailView!.isHidden = false
            backgroundColor = NCBrandColor.sharedInstance.backgroundView
            backgroundView.backgroundColor = backgroundColor
            
        } else {
            
            navigationController.isNavigationBarHidden = true
            pdfThumbnailView!.isHidden = true
            backgroundColor = .black
            backgroundView.backgroundColor = backgroundColor
        }
    
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) {
            let size = self.backgroundView!.bounds
            let height = size.height - size.origin.y 
            self.frame = CGRect(x: 0, y: 0, width: size.width, height: height)
        }
    }
}
