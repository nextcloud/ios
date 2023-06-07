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
import EasyTipView
import NextcloudKit

class NCViewerPDF: UIViewController, NCViewerPDFSearchDelegate {

    @IBOutlet weak var pdfContainer: UIView!

    var metadata = tableMetadata()
    var imageIcon: UIImage?

    private var filePath = ""

    private var pdfView = PDFView()
    private var pdfThumbnailScrollView = UIScrollView()
    private var pdfThumbnailView = PDFThumbnailView()
    private var pdfDocument: PDFDocument?
    private let pageView = UIView()
    private let pageViewLabel = UILabel()
    private var tipView: EasyTipView?

    private let thumbnailViewHeight: CGFloat = 70
    private let thumbnailViewWidth: CGFloat = 80
    private let thumbnailPadding: CGFloat = 2
    private let animateDuration: TimeInterval = 0.3
    private let pageViewtopAnchor: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 10 : 30
    private let window = UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.first { $0.isKeyWindow }

    private var defaultBackgroundColor: UIColor = .clear

    private var pdfThumbnailScrollViewTopAnchor: NSLayoutConstraint?
    private var pdfThumbnailScrollViewTrailingAnchor: NSLayoutConstraint?
    private var pdfThumbnailScrollViewWidthAnchor: NSLayoutConstraint?
    private var pageViewWidthAnchor: NSLayoutConstraint?

    private var hideStatusBar: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {

        filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        pdfDocument = PDFDocument(url: URL(fileURLWithPath: filePath))
        defaultBackgroundColor = pdfView.backgroundColor
        view.backgroundColor = defaultBackgroundColor

        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "more")!.image(color: .label, size: 25), style: .plain, target: self, action: #selector(self.openMenuMore))
        navigationItem.title = metadata.fileNameView

        NotificationCenter.default.addObserver(self, selector: #selector(favoriteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadStartFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuDetailClose), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(searchText), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuSearchTextPDF), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(goToPage), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuGotToPageInPDF), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handlePageChange), name: Notification.Name.PDFViewPageChanged, object: nil)

        // Tip
        var preferences = EasyTipView.Preferences()
        preferences.drawing.foregroundColor = .white
        preferences.drawing.backgroundColor = NCBrandColor.shared.nextcloud
        preferences.drawing.textAlignment = .left
        preferences.drawing.arrowPosition = .right
        preferences.drawing.cornerRadius = 10

        preferences.positioning.bubbleInsets.right = window?.safeAreaInsets.right ?? 0

        preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: 100)
        preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -100)
        preferences.animating.showInitialAlpha = 0
        preferences.animating.showDuration = 1.5
        preferences.animating.dismissDuration = 1.5

        tipView = EasyTipView(text: NSLocalizedString("_tip_pdf_thumbnails_", comment: ""), preferences: preferences, delegate: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        createview()
        showTip()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        tipView?.dismiss()

        coordinator.animate(alongsideTransition: { context in
            self.pdfThumbnailScrollViewTrailingAnchor?.constant = self.thumbnailViewWidth + (self.window?.safeAreaInsets.right ?? 0)
            self.pdfThumbnailScrollView.isHidden = true
        }, completion: { context in
            self.setConstraints()
            self.showTip()
        })
    }

    override var prefersStatusBarHidden: Bool {
        return hideStatusBar
    }

    @objc func viewUnload() {

        navigationController?.popViewController(animated: true)
    }

    func createview() {

        // PDF VIEW

        pdfView = PDFView(frame: CGRect(x: 0, y: 0, width: pdfContainer.frame.width, height: pdfContainer.frame.height))
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleLeftMargin]
        pdfView.document = pdfDocument
        pdfView.document?.page(at: 0)?.annotations.forEach({
            $0.isReadOnly = true
        })
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfContainer.addSubview(pdfView)

        // PDF THUMBNAIL

        pdfThumbnailScrollView.translatesAutoresizingMaskIntoConstraints = false
        pdfThumbnailScrollView.backgroundColor = defaultBackgroundColor
        pdfThumbnailScrollView.showsVerticalScrollIndicator = false
        pdfContainer.addSubview(pdfThumbnailScrollView)

        pdfThumbnailScrollView.bottomAnchor.constraint(equalTo: pdfContainer.bottomAnchor).isActive = true
        pdfThumbnailScrollViewTopAnchor = pdfThumbnailScrollView.topAnchor.constraint(equalTo: pdfContainer.safeAreaLayoutGuide.topAnchor)
        pdfThumbnailScrollViewTopAnchor?.isActive = true
        pdfThumbnailScrollViewTrailingAnchor = pdfThumbnailScrollView.trailingAnchor.constraint(equalTo: pdfContainer.trailingAnchor)
        pdfThumbnailScrollViewTrailingAnchor?.isActive = true
        pdfThumbnailScrollViewWidthAnchor = pdfThumbnailScrollView.widthAnchor.constraint(equalToConstant: thumbnailViewWidth)
        pdfThumbnailScrollViewWidthAnchor?.isActive = true

        pdfThumbnailView.translatesAutoresizingMaskIntoConstraints = false
        pdfThumbnailView.pdfView = pdfView
        pdfThumbnailView.layoutMode = .vertical
        pdfThumbnailView.thumbnailSize = CGSize(width: thumbnailViewHeight, height: thumbnailViewHeight)
        pdfThumbnailView.backgroundColor = .clear

        pdfThumbnailScrollView.isHidden = true
        pdfThumbnailScrollView.addSubview(pdfThumbnailView)

        NSLayoutConstraint.activate([
            pdfThumbnailView.topAnchor.constraint(equalTo: pdfThumbnailScrollView.topAnchor),
            pdfThumbnailView.bottomAnchor.constraint(equalTo: pdfThumbnailScrollView.bottomAnchor),
            pdfThumbnailView.leadingAnchor.constraint(equalTo: pdfThumbnailScrollView.leadingAnchor),
            pdfThumbnailView.leadingAnchor.constraint(equalTo: pdfThumbnailScrollView.trailingAnchor, constant: (window?.safeAreaInsets.left ?? 0)),
            pdfThumbnailView.widthAnchor.constraint(equalToConstant: thumbnailViewWidth)
        ])
        let contentViewCenterY = pdfThumbnailView.centerYAnchor.constraint(equalTo: pdfThumbnailScrollView.centerYAnchor)
        contentViewCenterY.priority = .defaultLow
        let pageCount = CGFloat(pdfDocument?.pageCount ?? 0)
        let contentViewHeight = pdfThumbnailView.heightAnchor.constraint(equalToConstant: CGFloat(pageCount * thumbnailViewHeight) + CGFloat(pageCount * thumbnailPadding) + 30)
        contentViewHeight.priority = .defaultLow
        NSLayoutConstraint.activate([
            contentViewCenterY,
            contentViewHeight
        ])

        // COUNTER PDF PAGE VIEW

        pageView.translatesAutoresizingMaskIntoConstraints = false
        pageView.layer.cornerRadius = 10
        pageView.backgroundColor = .systemBackground.withAlphaComponent(
            UIAccessibility.isReduceTransparencyEnabled ? 1 : 0.5
        )
        pdfContainer.addSubview(pageView)

        NSLayoutConstraint.activate([
            pageView.topAnchor.constraint(equalTo: pdfContainer.safeAreaLayoutGuide.topAnchor, constant: pageViewtopAnchor),
            pageView.heightAnchor.constraint(equalToConstant: 30),
            pageView.leftAnchor.constraint(equalTo: pdfContainer.safeAreaLayoutGuide.leftAnchor, constant: 10)
        ])
        pageViewWidthAnchor = pageView.widthAnchor.constraint(equalToConstant: 10)
        pageViewWidthAnchor?.isActive = true

        pageViewLabel.translatesAutoresizingMaskIntoConstraints = false
        pageViewLabel.textAlignment = .center
        pageViewLabel.textColor = .label
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
        swipePdfView.delegate = self
        pdfView.addGestureRecognizer(swipePdfView)

        let edgePdfView = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(gestureOpenPdfThumbnail))
        edgePdfView.edges = .right
        edgePdfView.delegate = self
        pdfView.addGestureRecognizer(edgePdfView)

        let swipePdfThumbnailScrollView = UISwipeGestureRecognizer(target: self, action: #selector(gestureClosePdfThumbnail))
        swipePdfThumbnailScrollView.direction = .right
        pdfThumbnailScrollView.addGestureRecognizer(swipePdfThumbnailScrollView)

        setConstraints()
        handlePageChange()
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

    // MARK: - Tip

    func showTip() {

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !NCManageDatabase.shared.tipExists(NCGlobal.shared.tipNCViewerPDFThumbnail) {
                self.tipView?.show(forView: self.pdfThumbnailScrollView, withinSuperview: self.pdfContainer)
            }
        }
    }

    // MARK: - NotificationCenter

    @objc func uploadStartFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.metadata.serverUrl,
              let fileName = userInfo["fileName"] as? String,
              fileName == self.metadata.fileName
        else { return }

        NCActivityIndicator.shared.start()
    }

    @objc func uploadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.metadata.serverUrl,
              let fileName = userInfo["fileName"] as? String,
              fileName == self.metadata.fileName,
              let error = userInfo["error"] as? NKError
        else {
            return
        }

        NCActivityIndicator.shared.stop()

        if error == .success {
            pdfDocument = PDFDocument(url: URL(fileURLWithPath: filePath))
            pdfView.document = pdfDocument
            pdfView.layoutDocumentView()
        }
    }

    @objc func favoriteFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              ocId == self.metadata.ocId,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else { return }

        self.metadata = metadata
    }

    @objc func moveFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              ocId == self.metadata.ocId,
              let ocIdNew = userInfo["ocIdNew"] as? String,
              let metadataNew = NCManageDatabase.shared.getMetadataFromOcId(ocIdNew)
        else { return }

        self.metadata = metadataNew
    }

    @objc func deleteFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? [String],
              let error = userInfo["error"] as? NKError
        else { return }

        if error == .success, let ocId = ocId.first, metadata.ocId == ocId {
            viewUnload()
        }
    }

    @objc func renameFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              ocId == self.metadata.ocId,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else { return }

        self.metadata = metadata
        navigationItem.title = metadata.fileNameView
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

        if pdfThumbnailScrollView.isHidden {

            if navigationController?.isNavigationBarHidden ?? false {
                navigationController?.setNavigationBarHidden(false, animated: true)
                hideStatusBar = false
                pdfThumbnailScrollViewTopAnchor = pdfThumbnailScrollView.topAnchor.constraint(equalTo: pdfContainer.safeAreaLayoutGuide.topAnchor)
            } else {
                navigationController?.setNavigationBarHidden(true, animated: true)
                hideStatusBar = true
                pdfThumbnailScrollViewTopAnchor = pdfThumbnailScrollView.topAnchor.constraint(equalTo: pdfContainer.topAnchor)
            }
        }

        handlePageChange()
        closePdfThumbnail()
    }

    @objc func gestureClosePdfThumbnail(_ recognizer: UIScreenEdgePanGestureRecognizer) {

        if recognizer.state == .recognized {
            closePdfThumbnail()
        }
    }

    @objc func gestureOpenPdfThumbnail(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        guard let pdfDocument = pdfView.document, !pdfDocument.isLocked else { return }

        OpenPdfThumbnail()
    }


    // MARK: - OPEN / CLOSE Thumbnail

    func OpenPdfThumbnail() {

        if let tipView = self.tipView {
            tipView.dismiss()
            NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCViewerPDFThumbnail)
            self.tipView = nil
        }
        self.pdfThumbnailScrollView.isHidden = false
        self.pdfThumbnailScrollViewWidthAnchor?.constant = thumbnailViewWidth + (window?.safeAreaInsets.right ?? 0)
        UIView.animate(withDuration: animateDuration, animations: {
            self.pdfThumbnailScrollViewTrailingAnchor?.constant = 0
            self.pdfContainer.layoutIfNeeded()
        })
    }

    func closePdfThumbnail() {
        guard !self.pdfThumbnailScrollView.isHidden else { return }

        UIView.animate(withDuration: animateDuration) {
            self.pdfThumbnailScrollViewTrailingAnchor?.constant = self.thumbnailViewWidth + (self.window?.safeAreaInsets.right ?? 0)
            self.pdfContainer.layoutIfNeeded()
        } completion: { _ in
            self.pdfThumbnailScrollView.isHidden = true
        }
    }

    // MARK: -

    func setConstraints() {

        let widthThumbnail = thumbnailViewWidth + (window?.safeAreaInsets.right ?? 0)

        UIView.animate(withDuration: animateDuration, animations: {
            // Close
            self.pdfThumbnailScrollView.isHidden = true
            self.pdfThumbnailScrollViewTrailingAnchor?.constant = widthThumbnail
            self.pdfThumbnailScrollViewWidthAnchor?.constant = widthThumbnail

            self.pdfContainer.layoutIfNeeded()
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

        removeAllAnnotations()

        pdfSelection.pages.forEach { page in
            let highlight = PDFAnnotation(bounds: pdfSelection.bounds(for: page), forType: .highlight, withProperties: nil)
            highlight.endLineStyle = .square
            highlight.color = .systemBlue
            page.addAnnotation(highlight)
        }
        if let page = pdfSelection.pages.first {
            pdfView.go(to: page)
        }
        handlePageChange()
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
                                                        message: NSLocalizedString("_the_entered_page_number_does_not_exist_", comment: ""),
                                                        preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }

    func removeAllAnnotations() {

        guard let document = pdfDocument else { return }

        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                let annotations = page.annotations
                for annotation in annotations {
                    page.removeAnnotation(annotation)
                }
            }
        }
    }
}

extension NCViewerPDF: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension NCViewerPDF: EasyTipViewDelegate {

    func easyTipViewDidTap(_ tipView: EasyTipView) {
        NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCViewerPDFThumbnail)
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) { }
}
