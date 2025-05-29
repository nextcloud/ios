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

    var metadata: tableMetadata?
    var url: URL?
    var titleView: String?
    var imageIcon: UIImage?

    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
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
    private let window = UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.first { $0.isKeyWindow }

    private var defaultBackgroundColor: UIColor = .clear

    private var pdfContainerTopAnchor: NSLayoutConstraint?
    private var pdfThumbnailScrollViewTopAnchor: NSLayoutConstraint?
    private var pdfThumbnailScrollViewTrailingAnchor: NSLayoutConstraint?
    private var pdfThumbnailScrollViewWidthAnchor: NSLayoutConstraint?
    private var pageViewWidthAnchor: NSLayoutConstraint?

    private var tipView: EasyTipView?

    var sceneIdentifier: String {
        (self.tabBarController as? NCMainTabBarController)?.sceneIdentifier ?? ""
    }

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {

        if let url = self.url {
            pdfDocument = PDFDocument(url: url)
        } else if let metadata = self.metadata {
            filePath = NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
            pdfDocument = PDFDocument(url: URL(fileURLWithPath: filePath))
            if NCNetworking.shared.isOnline {
                navigationItem.rightBarButtonItem = UIBarButtonItem(image: NCImageCache.shared.getImageButtonMore(), style: .plain, target: self, action: #selector(openMenuMore(_:)))
            }
        }
        defaultBackgroundColor = pdfView.backgroundColor
        view.backgroundColor = defaultBackgroundColor

        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.title = titleView

        // PDF CONTAINER

        pdfContainer.translatesAutoresizingMaskIntoConstraints = false
        pdfContainerTopAnchor = pdfContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        pdfContainerTopAnchor?.isActive = true
        NSLayoutConstraint.activate([
            pdfContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pdfContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            pdfContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])

        // PDF VIEW

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.document = pdfDocument
        pdfView.document?.page(at: 0)?.annotations.forEach({
            $0.isReadOnly = true
        })
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfContainer.addSubview(pdfView)

        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: pdfContainer.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: pdfContainer.safeAreaLayoutGuide.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: pdfContainer.safeAreaLayoutGuide.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: pdfContainer.bottomAnchor)
        ])

        // MODAL
        if self.navigationController?.presentingViewController != nil {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .plain, target: self, action: #selector(viewDismiss))
        }

        // NOTIFIFICATION

        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(searchText), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuSearchTextPDF), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(goToPage), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuGotToPageInPDF), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handlePageChange), name: Notification.Name.PDFViewPageChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuSearchTextPDF), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuGotToPageInPDF), object: nil)

        NotificationCenter.default.removeObserver(self, name: Notification.Name.PDFViewPageChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // PDF THUMBNAIL

        pdfThumbnailScrollView.translatesAutoresizingMaskIntoConstraints = false
        pdfThumbnailScrollView.backgroundColor = defaultBackgroundColor
        pdfThumbnailScrollView.showsVerticalScrollIndicator = false
        pdfContainer.addSubview(pdfThumbnailScrollView)

        NSLayoutConstraint.activate([
            pdfThumbnailScrollView.bottomAnchor.constraint(equalTo: pdfContainer.bottomAnchor)
        ])
        pdfThumbnailScrollViewTopAnchor = pdfThumbnailScrollView.topAnchor.constraint(equalTo: pdfContainer.safeAreaLayoutGuide.topAnchor)
        pdfThumbnailScrollViewTopAnchor?.isActive = true
        pdfThumbnailScrollViewTrailingAnchor = pdfThumbnailScrollView.trailingAnchor.constraint(equalTo: pdfContainer.trailingAnchor, constant: thumbnailViewWidth + (window?.safeAreaInsets.right ?? 0))
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
            pageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15),
            pageView.heightAnchor.constraint(equalToConstant: 30),
            pageView.leftAnchor.constraint(equalTo: pdfContainer.safeAreaLayoutGuide.leftAnchor, constant: 10)
        ])
        pageViewWidthAnchor = pageView.widthAnchor.constraint(equalToConstant: 10)
        pageViewWidthAnchor?.isActive = true

        pageViewLabel.translatesAutoresizingMaskIntoConstraints = false
        pageViewLabel.textAlignment = .center
        pageViewLabel.textColor = NCBrandColor.shared.textColor
        pageView.addSubview(pageViewLabel)

        NSLayoutConstraint.activate([
            pageViewLabel.topAnchor.constraint(equalTo: pageView.topAnchor),
            pageViewLabel.leftAnchor.constraint(equalTo: pageView.leftAnchor),
            pageViewLabel.rightAnchor.constraint(equalTo: pageView.rightAnchor),
            pageViewLabel.bottomAnchor.constraint(equalTo: pageView.bottomAnchor)
        ])

        // GESTURE

        let tapPdfView = UITapGestureRecognizer(target: self, action: #selector(tapPdfView(_:)))
        tapPdfView.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(tapPdfView)

        // recognize single / double tap
        for gesture in pdfView.gestureRecognizers! {
            tapPdfView.require(toFail: gesture)
        }

        let swipePdfView = UISwipeGestureRecognizer(target: self, action: #selector(gestureClosePdfThumbnail(_:)))
        swipePdfView.direction = .right
        swipePdfView.delegate = self
        pdfView.addGestureRecognizer(swipePdfView)

        let edgePdfView = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(gestureOpenPdfThumbnail(_:)))
        edgePdfView.edges = .right
        edgePdfView.delegate = self
        pdfView.addGestureRecognizer(edgePdfView)

        let swipePdfThumbnailScrollView = UISwipeGestureRecognizer(target: self, action: #selector(gestureClosePdfThumbnail(_:)))
        swipePdfThumbnailScrollView.direction = .right
        pdfThumbnailScrollView.addGestureRecognizer(swipePdfThumbnailScrollView)

        handlePageChange()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NCNetworking.shared.addDelegate(self)

        showTip()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        NCNetworking.shared.removeDelegate(self)

        dismissTip()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        dismissTip()
        coordinator.animate(alongsideTransition: { _ in
            self.pdfThumbnailScrollViewTrailingAnchor?.constant = self.thumbnailViewWidth + (self.window?.safeAreaInsets.right ?? 0)
            self.pdfThumbnailScrollView.isHidden = true
        }, completion: { _ in
            self.pdfView.autoScales = true
        })
    }

    @objc func viewUnload() {
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: true)
        }
    }

    @objc func viewDismiss() {
        DispatchQueue.main.async {
            self.dismiss(animated: true)
        }
    }

    // MARK: - NotificationCenter

    @objc func searchText() {
        if let viewerPDFSearch = UIStoryboard(name: "NCViewerPDF", bundle: nil).instantiateViewController(withIdentifier: "NCViewerPDFSearch") as? NCViewerPDFSearch {
            viewerPDFSearch.delegate = self
            viewerPDFSearch.pdfDocument = pdfDocument
            let navigaionController = UINavigationController(rootViewController: viewerPDFSearch)
            self.present(navigaionController, animated: true)
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

    @objc private func openMenuMore(_ sender: Any?) {
        guard let metadata = self.metadata else { return }
        if imageIcon == nil {
            imageIcon = UIImage(named: "file_pdf")
        }

        NCViewer().toggleMenu(controller: (self.tabBarController as? NCMainTabBarController), metadata: metadata, webView: false, imageIcon: imageIcon, sender: sender)
    }

    // MARK: - Gesture Recognizer

    @objc func tapPdfView(_ recognizer: UITapGestureRecognizer) {
        if pdfThumbnailScrollView.isHidden {
            if navigationController?.isNavigationBarHidden ?? false {
                navigationController?.setNavigationBarHidden(false, animated: true)
            } else {
                navigationController?.setNavigationBarHidden(true, animated: true)
            }
        }

        UIView.animate(withDuration: 0.0, animations: {
            self.pdfContainerTopAnchor?.isActive = false
            if let barHidden = self.navigationController?.isNavigationBarHidden, barHidden {
                self.pdfContainerTopAnchor = self.pdfContainer.topAnchor.constraint(equalTo: self.view.topAnchor)
            } else {
                self.pdfContainerTopAnchor = self.pdfContainer.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor)
            }
            self.pdfContainerTopAnchor?.isActive = true
        })

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
        openPdfThumbnail()
    }

    // MARK: - OPEN / CLOSE Thumbnail

    func openPdfThumbnail() {
        self.dismissTip()
        self.pdfThumbnailScrollView.isHidden = false
        self.pdfThumbnailScrollViewWidthAnchor?.constant = thumbnailViewWidth + (window?.safeAreaInsets.right ?? 0)
        self.pdfThumbnailScrollViewTopAnchor?.isActive = false

        if let barHidden = self.navigationController?.isNavigationBarHidden, barHidden {
            self.pdfThumbnailScrollViewTopAnchor = self.pdfThumbnailScrollView.topAnchor.constraint(equalTo: self.view.topAnchor)
        } else {
            self.pdfThumbnailScrollViewTopAnchor = self.pdfThumbnailScrollView.topAnchor.constraint(equalTo: self.pdfContainer.safeAreaLayoutGuide.topAnchor)
        }
        self.pdfThumbnailScrollViewTopAnchor?.isActive = true

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

    @objc func handlePageChange() {
        guard let curPage = pdfView.currentPage?.pageRef?.pageNumber else { pageView.alpha = 0; return }
        guard let totalPages = pdfView.document?.pageCount else { return }
        let visibleRect = CGRect(x: pdfThumbnailScrollView.contentOffset.x, y: pdfThumbnailScrollView.contentOffset.y, width: pdfThumbnailScrollView.bounds.size.width, height: pdfThumbnailScrollView.bounds.size.height)
        let centerPoint = CGPoint(x: visibleRect.size.width / 2, y: visibleRect.size.height / 2)
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
    func showTip() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !NCManageDatabase.shared.tipExists(NCGlobal.shared.tipPDFThumbnail) {
                var preferences = EasyTipView.Preferences()
                preferences.drawing.foregroundColor = .white
                preferences.drawing.backgroundColor = .lightGray
                preferences.drawing.textAlignment = .left
                preferences.drawing.arrowPosition = .right
                preferences.drawing.cornerRadius = 10

                preferences.positioning.bubbleInsets.right = self.window?.safeAreaInsets.right ?? 0

                preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: 100)
                preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -100)
                preferences.animating.showInitialAlpha = 0
                preferences.animating.showDuration = 1.5
                preferences.animating.dismissDuration = 1.5

                if self.tipView == nil {
                    self.tipView = EasyTipView(text: NSLocalizedString("_tip_pdf_thumbnails_", comment: ""), preferences: preferences, delegate: self)
                    self.tipView?.show(forView: self.pdfThumbnailScrollView, withinSuperview: self.pdfContainer)
                }
            }
        }
    }

    func easyTipViewDidTap(_ tipView: EasyTipView) {
        NCManageDatabase.shared.addTip(NCGlobal.shared.tipPDFThumbnail)
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) { }

    func dismissTip() {
        if !NCManageDatabase.shared.tipExists(NCGlobal.shared.tipPDFThumbnail) {
            NCManageDatabase.shared.addTip(NCGlobal.shared.tipPDFThumbnail)
        }
        tipView?.dismiss()
        tipView = nil
    }
}

extension NCViewerPDF: NCTransferDelegate {
    func transferChange(status: String, metadatasError: [tableMetadata: NKError]) {
        switch status {
        /// DELETE
        case NCGlobal.shared.networkingStatusDelete:
            let shouldUnloadView = metadatasError.contains { key, error in
                key.ocId == self.metadata?.ocId && error == .success
            }
            if shouldUnloadView {
                self.viewUnload()
            }
        default:
            break
        }
    }

    func transferChange(status: String, metadata: tableMetadata, error: NKError) {
        guard self.metadata?.serverUrl == metadata.serverUrl,
              self.metadata?.fileNameView == metadata.fileNameView
        else {
            return
        }

        DispatchQueue.main.async {
            switch status {
            /// UPLOAD
            case NCGlobal.shared.networkingStatusUploading:
                NCActivityIndicator.shared.start()
            case NCGlobal.shared.networkingStatusUploaded:
                NCActivityIndicator.shared.stop()
                if error == .success {
                    self.pdfDocument = PDFDocument(url: URL(fileURLWithPath: self.filePath))
                    self.pdfView.document = self.pdfDocument
                    self.pdfView.layoutDocumentView()
                }
            /// FAVORITE
            case NCGlobal.shared.networkingStatusFavorite:
                if self.metadata?.ocId == metadata.ocId {
                    self.metadata = metadata
                }
            default:
                break
            }
        }
    }
}
