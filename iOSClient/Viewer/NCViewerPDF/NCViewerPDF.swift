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

import UIKit
import PDFKit
import SwiftUI

class NCViewerPDF: UIViewController, NCViewerPDFSearchDelegate, UIGestureRecognizerDelegate {

    var metadata = tableMetadata()
    var imageIcon: UIImage?

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var filePath = ""

    private var pdfView = PDFView()
    private var pdfThumbnailScrollView = UIScrollView()
    private var pdfThumbnailView = PDFThumbnailView()
    private var pdfDocument: PDFDocument?
    private let pageView = UIView()
    private let pageViewLabel = UILabel()

    private let thumbnailViewHeight: CGFloat = 70
    private let thumbnailViewWidth: CGFloat = 80
    private let thumbnailPadding: CGFloat = 2
    private let animateDuration: TimeInterval = 0.3

    private var defaultBackgroundColor: UIColor = .clear

    private var pdfThumbnailScrollViewTrailingAnchor: NSLayoutConstraint?
    private var pdfThumbnailScrollViewWidthAnchor: NSLayoutConstraint?
    private var pageViewWidthAnchor: NSLayoutConstraint?

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {

        filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        pdfDocument = PDFDocument(url: URL(fileURLWithPath: filePath))
        let pageCount = CGFloat(pdfDocument?.pageCount ?? 0)
        defaultBackgroundColor = pdfView.backgroundColor
        view.backgroundColor = defaultBackgroundColor

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "more")!.image(color: NCBrandColor.shared.label, size: 25), style: .plain, target: self, action: #selector(self.openMenuMore))
        navigationItem.title = metadata.fileNameView

        // PDF VIEW

        pdfView = PDFView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        view.addSubview(pdfView)

        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
        ])
        if UIDevice.current.userInterfaceIdiom == .pad {
            pdfView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -thumbnailViewWidth).isActive = true
        } else {
            pdfView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        }

        // PDF THUMBNAIL

        pdfThumbnailScrollView.translatesAutoresizingMaskIntoConstraints = false
        pdfThumbnailScrollView.backgroundColor = defaultBackgroundColor
        pdfThumbnailScrollView.showsVerticalScrollIndicator = false
        view.addSubview(pdfThumbnailScrollView)

        NSLayoutConstraint.activate([
            pdfThumbnailScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfThumbnailScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        pdfThumbnailScrollViewTrailingAnchor = pdfThumbnailScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        pdfThumbnailScrollViewTrailingAnchor?.isActive = true
        pdfThumbnailScrollViewWidthAnchor = pdfThumbnailScrollView.widthAnchor.constraint(equalToConstant: thumbnailViewWidth)
        pdfThumbnailScrollViewWidthAnchor?.isActive = true

        pdfThumbnailView.translatesAutoresizingMaskIntoConstraints = false
        pdfThumbnailView.pdfView = pdfView
        pdfThumbnailView.layoutMode = .vertical
        pdfThumbnailView.thumbnailSize = CGSize(width: thumbnailViewHeight, height: thumbnailViewHeight)
        pdfThumbnailView.backgroundColor = .clear
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.pdfThumbnailScrollView.isHidden = false
        } else {
            self.pdfThumbnailScrollView.isHidden = true
        }
        pdfThumbnailScrollView.addSubview(pdfThumbnailView)

        NSLayoutConstraint.activate([
            pdfThumbnailView.topAnchor.constraint(equalTo: pdfThumbnailScrollView.topAnchor),
            pdfThumbnailView.bottomAnchor.constraint(equalTo: pdfThumbnailScrollView.bottomAnchor),
            pdfThumbnailView.leadingAnchor.constraint(equalTo: pdfThumbnailScrollView.leadingAnchor),
            pdfThumbnailView.leadingAnchor.constraint(equalTo: pdfThumbnailScrollView.trailingAnchor, constant: (UIApplication.shared.keyWindow?.safeAreaInsets.left ?? 0)),
            pdfThumbnailView.widthAnchor.constraint(equalToConstant: thumbnailViewWidth)
        ])
        let contentViewCenterY = pdfThumbnailView.centerYAnchor.constraint(equalTo: pdfThumbnailScrollView.centerYAnchor)
        contentViewCenterY.priority = .defaultLow
        let contentViewHeight = pdfThumbnailView.heightAnchor.constraint(equalToConstant: CGFloat(pageCount * thumbnailViewHeight) + CGFloat(pageCount * thumbnailPadding) + 30)
        contentViewHeight.priority = .defaultLow
        NSLayoutConstraint.activate([
            contentViewCenterY,
            contentViewHeight
        ])

        // COUNTER PDF PAGE VIEW

        pageView.translatesAutoresizingMaskIntoConstraints = false
        pageView.layer.cornerRadius = 10
        pageView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        view.addSubview(pageView)

        NSLayoutConstraint.activate([
            pageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            pageView.heightAnchor.constraint(equalToConstant: 30),
            pageView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 10)
        ])
        pageViewWidthAnchor = pageView.widthAnchor.constraint(equalToConstant: 10)
        pageViewWidthAnchor?.isActive = true

        pageViewLabel.translatesAutoresizingMaskIntoConstraints = false
        pageViewLabel.textAlignment = .center
        pageViewLabel.textColor = .gray
        pageView.addSubview(pageViewLabel)

        NSLayoutConstraint.activate([
            pageViewLabel.topAnchor.constraint(equalTo: pageView.topAnchor),
            pageViewLabel.leftAnchor.constraint(equalTo: pageView.leftAnchor),
            pageViewLabel.rightAnchor.constraint(equalTo: pageView.rightAnchor),
            pageViewLabel.bottomAnchor.constraint(equalTo: pageView.bottomAnchor)
        ])

        // GESTURE

        let tapPdfView = UITapGestureRecognizer(target: self, action: #selector(tapPdfView))
        tapPdfView.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(tapPdfView)

        // recognize single / double tap
        for gesture in pdfView.gestureRecognizers! {
            tapPdfView.require(toFail: gesture)
        }

        let swipePdfView = UISwipeGestureRecognizer(target: self, action: #selector(gestureClosePdfThumbnail))
        swipePdfView.direction = .right
        pdfView.addGestureRecognizer(swipePdfView)

        let swipePdfThumbnailScrollView = UISwipeGestureRecognizer(target: self, action: #selector(gestureClosePdfThumbnail))
        swipePdfThumbnailScrollView.direction = .right
        pdfThumbnailScrollView.addGestureRecognizer(swipePdfThumbnailScrollView)

        let edgePdfView = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(gestureOpenPdfThumbnail))
        edgePdfView.edges = .right
        pdfView.addGestureRecognizer(edgePdfView)

        let edgeView = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(gestureOpenPdfThumbnail))
        edgeView.edges = .right
        view.addGestureRecognizer(edgeView)

        NotificationCenter.default.addObserver(self, selector: #selector(favoriteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuDetailClose), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(searchText), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuSearchTextPDF), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(goToPage), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuGotToPageInPDF), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handlePageChange), name: Notification.Name.PDFViewPageChanged, object: nil)

        setConstraints()
        handlePageChange()
    }

    @objc func viewUnload() {

        navigationController?.popViewController(animated: true)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { context in
            if UIDevice.current.userInterfaceIdiom == .phone {
                // Close
                self.pdfThumbnailScrollViewTrailingAnchor?.constant = self.thumbnailViewWidth + (UIApplication.shared.keyWindow?.safeAreaInsets.right ?? 0)
                self.pdfThumbnailScrollView.isHidden = true
            }
        }, completion: { context in
            self.setConstraints()
        })
    }

    deinit {

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuDetailClose), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuSearchTextPDF), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuGotToPageInPDF), object: nil)

        NotificationCenter.default.removeObserver(self, name: Notification.Name.PDFViewPageChanged, object: nil)
    }

    // MARK: - NotificationCenter

    @objc func uploadedFile(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId), let errorCode = userInfo["errorCode"] as? Int {
                if errorCode == 0  && metadata.ocId == self.metadata.ocId {
                    pdfDocument = PDFDocument(url: URL(fileURLWithPath: filePath))
                    pdfView.document = pdfDocument
                    pdfView.layoutDocumentView()
                }
            }
        }
    }

    @objc func favoriteFile(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {

                if metadata.ocId == self.metadata.ocId {
                    self.metadata = metadata
                }
            }
        }
    }

    @objc func moveFile(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let ocIdNew = userInfo["ocIdNew"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId), let metadataNew = NCManageDatabase.shared.getMetadataFromOcId(ocIdNew) {

                if metadata.ocId == self.metadata.ocId {
                    self.metadata = metadataNew
                }
            }
        }
    }

    @objc func deleteFile(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["OcId"] as? String {
                if ocId == self.metadata.ocId {
                    viewUnload()
                }
            }
        }
    }

    @objc func renameFile(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {

                if metadata.ocId == self.metadata.ocId {
                    self.metadata = metadata
                    navigationItem.title = metadata.fileNameView
                }
            }
        }
    }

    @objc func searchText() {

        let viewerPDFSearch = UIStoryboard(name: "NCViewerPDF", bundle: nil).instantiateViewController(withIdentifier: "NCViewerPDFSearch") as! NCViewerPDFSearch
        viewerPDFSearch.delegate = self
        viewerPDFSearch.pdfDocument = pdfDocument

        let navigaionController = UINavigationController(rootViewController: viewerPDFSearch)
        self.present(navigaionController, animated: true)
    }

    @objc func goToPage() {

        guard let pdfDocument = pdfView.document else { return }

        let alertMessage = NSString(format: NSLocalizedString("_this_document_has_%@_pages_", comment: "") as NSString, "\(pdfDocument.pageCount)") as String
        let alertController = UIAlertController(title: NSLocalizedString("_go_to_page_", comment: ""), message: alertMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))

        alertController.addTextField(configurationHandler: { textField in
            textField.placeholder = NSLocalizedString("_page_", comment: "")
            textField.keyboardType = .decimalPad
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { [unowned self] _ in
            if let pageLabel = alertController.textFields?.first?.text {
                self.selectPage(with: pageLabel)
            }
        }))

        self.present(alertController, animated: true)
    }

    // MARK: - Action

    @objc func openMenuMore() {

        if imageIcon == nil { imageIcon = UIImage(named: "file_pdf") }
        NCViewer.shared.toggleMenu(viewController: self, metadata: metadata, webView: false, imageIcon: imageIcon)
    }

    // MARK: - Gesture Recognizer

    @objc func tapPdfView(_ recognizer: UITapGestureRecognizer) {

        if navigationController?.isNavigationBarHidden ?? false {
            navigationController?.setNavigationBarHidden(false, animated: true)
        } else {
            navigationController?.setNavigationBarHidden(true, animated: true)
        }
    }

    @objc func gestureOpenPdfThumbnail(_ recognizer: UIScreenEdgePanGestureRecognizer) {

        if UIDevice.current.userInterfaceIdiom == .phone && self.pdfThumbnailScrollView.isHidden {
            self.pdfThumbnailScrollView.isHidden = false
            self.pdfThumbnailScrollViewWidthAnchor?.constant = thumbnailViewWidth + (UIApplication.shared.keyWindow?.safeAreaInsets.right ?? 0)
            UIView.animate(withDuration: animateDuration, animations: {
                self.pdfThumbnailScrollViewTrailingAnchor?.constant = 0
                self.view.layoutIfNeeded()
            })
        }
    }

    @objc func gestureClosePdfThumbnail(_ recognizer: UIScreenEdgePanGestureRecognizer) {

        if recognizer.state == .recognized && UIDevice.current.userInterfaceIdiom == .phone && !self.pdfThumbnailScrollView.isHidden {
            UIView.animate(withDuration: animateDuration) {
                self.pdfThumbnailScrollViewTrailingAnchor?.constant = self.thumbnailViewWidth + (UIApplication.shared.keyWindow?.safeAreaInsets.right ?? 0)
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.pdfThumbnailScrollView.isHidden = true
            }
        }
    }

    // MARK: -

    func setConstraints() {

        let widthThumbnail = thumbnailViewWidth + (UIApplication.shared.keyWindow?.safeAreaInsets.right ?? 0)

        UIView.animate(withDuration: animateDuration, animations: {
            if UIDevice.current.userInterfaceIdiom == .phone {
                // Close
                self.pdfThumbnailScrollView.isHidden = true
                self.pdfThumbnailScrollViewTrailingAnchor?.constant = widthThumbnail
                self.pdfThumbnailScrollViewWidthAnchor?.constant = widthThumbnail
            } else {
                // Open
                self.pdfThumbnailScrollViewTrailingAnchor?.constant = 0
                self.pdfThumbnailScrollViewWidthAnchor?.constant = widthThumbnail
            }
            self.view.layoutIfNeeded()
            self.pdfView.autoScales = true
        })
    }

    @objc func handlePageChange() {

        guard let curPage = pdfView.currentPage?.pageRef?.pageNumber else { pageView.alpha = 0; return }
        guard let totalPages = pdfView.document?.pageCount else { return }

        let visibleRect = CGRect(x: pdfThumbnailScrollView.contentOffset.x, y: pdfThumbnailScrollView.contentOffset.y, width: pdfThumbnailScrollView.bounds.size.width, height: pdfThumbnailScrollView.bounds.size.height)
        let centerPoint = CGPoint(x: visibleRect.size.width/2, y: visibleRect.size.height/2)
        let currentPageY = CGFloat(curPage) * thumbnailViewHeight + CGFloat(curPage) * thumbnailPadding
        var gotoY = currentPageY - centerPoint.y

        let startY = visibleRect.origin.y < 0 ? 0 : (visibleRect.origin.y + thumbnailViewHeight)
        let endY = visibleRect.origin.y + visibleRect.height

        if currentPageY < startY {
            if gotoY < 0 { gotoY = 0 }
            pdfThumbnailScrollView.setContentOffset(CGPoint(x: 0, y: gotoY), animated: true)
        } else if currentPageY > endY {
            if gotoY > pdfThumbnailView.frame.height - visibleRect.height {
                gotoY = pdfThumbnailView.frame.height - visibleRect.height
            }
            pdfThumbnailScrollView.setContentOffset(CGPoint(x: 0, y: gotoY), animated: true)
        } else {
            print("visible")
        }

        pageView.alpha = 1
        pageViewLabel.text = String(curPage) + " " + NSLocalizedString("_of_", comment: "") + " " + String(totalPages)
        pageViewWidthAnchor?.constant = pageViewLabel.intrinsicContentSize.width + 10

        UIView.animate(withDuration: 1.0, delay: 2.5, animations: {
            self.pageView.alpha = 0
        })
    }

    func searchPdfSelection(_ pdfSelection: PDFSelection) {

        pdfSelection.color = .yellow
        pdfView.currentSelection = pdfSelection
        pdfView.go(to: pdfSelection)
    }

    private func selectPage(with label: String) {

        guard let pdf = pdfView.document else { return }

         if let pageNr = Int(label) {
             if pageNr > 0 && pageNr <= pdf.pageCount {
                 if let page = pdf.page(at: pageNr - 1) {
                     self.pdfView.go(to: page)
                 }
             } else {
                 let alertController = UIAlertController(title: NSLocalizedString("_invalid_page_", comment: ""),
                                                         message: NSLocalizedString("_the_entered_page_number_doesn't_exist_", comment: ""),
                                                         preferredStyle: .alert)
                 alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: nil))
                 self.present(alertController, animated: true, completion: nil)
             }
         }
     }
}
