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

class NCViewerPDF: UIViewController, NCViewerPDFSearchDelegate {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadata = tableMetadata()
    var imageIcon: UIImage?

    private var pdfView = PDFView()
    private var thumbnailViewHeight: CGFloat = 40
    private var pdfThumbnailView = PDFThumbnailView()
    private var pdfDocument: PDFDocument?
    private let pageView = UIView()
    private let pageViewLabel = UILabel()
    private var pageViewWidthAnchor: NSLayoutConstraint?
    private var filePath = ""

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {

        filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

        pdfView = PDFView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        pdfDocument = PDFDocument(url: URL(fileURLWithPath: filePath))

        pdfView.document = pdfDocument
        pdfView.backgroundColor = NCBrandColor.shared.systemBackground
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.displayDirection = CCUtility.getPDFDisplayDirection()
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleBottomMargin]
        pdfView.usePageViewController(true, withViewOptions: nil)

        view.addSubview(pdfView)

        pdfThumbnailView.translatesAutoresizingMaskIntoConstraints = false
        pdfThumbnailView.pdfView = pdfView
        pdfThumbnailView.layoutMode = .horizontal
        pdfThumbnailView.thumbnailSize = CGSize(width: 40, height: thumbnailViewHeight)
        pdfThumbnailView.backgroundColor = .clear
        // pdfThumbnailView.layer.shadowOffset.height = -5
        // pdfThumbnailView.layer.shadowOpacity = 0.25

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

        pdfView.backgroundColor = NCBrandColor.shared.systemBackground
        pdfView.layoutIfNeeded()
        handlePageChange()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(tapGesture)

        // recognize single / double tap
        for gesture in pdfView.gestureRecognizers! {
            tapGesture.require(toFail: gesture)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        //
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuDetailClose), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(searchText), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuSearchTextPDF), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(direction(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuPDFDisplayDirection), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(goToPage), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuGotToPageInPDF), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePageChange), name: Notification.Name.PDFViewPageChanged, object: nil)

        //
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "more")!.image(color: NCBrandColor.shared.label, size: 25), style: .plain, target: self, action: #selector(self.openMenuMore))

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.title = metadata.fileNameView
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuDetailClose), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuSearchTextPDF), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuPDFDisplayDirection), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuGotToPageInPDF), object: nil)

        NotificationCenter.default.removeObserver(self, name: Notification.Name.PDFViewPageChanged, object: nil)
    }

    @objc func viewUnload() {

        navigationController?.popViewController(animated: true)
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

    @objc func direction(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let direction = userInfo["direction"] as? PDFDisplayDirection {
                pdfView.displayDirection = direction
                CCUtility.setPDFDisplayDirection(direction)
                handlePageChange()
            }
        }
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

    @objc func didTap(_ recognizer: UITapGestureRecognizer) {

        if navigationController?.isNavigationBarHidden ?? false {

            navigationController?.setNavigationBarHidden(false, animated: false)
            pdfThumbnailView.isHidden = false
            pdfView.backgroundColor = NCBrandColor.shared.systemBackground

        } else {

            let point = recognizer.location(in: pdfView)
            if point.y > pdfView.frame.height - thumbnailViewHeight { return }

            navigationController?.setNavigationBarHidden(true, animated: false)
            pdfThumbnailView.isHidden = true
            pdfView.backgroundColor = .black
        }

        handlePageChange()
    }

    // MARK: -

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
