//
//  NCScan.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/08/18.
//  Copyright (c) 2018 Marino Faggiana. All rights reserved.
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
import Photos
import EasyTipView
import SwiftUI

class NCScan: UIViewController, NCScanCellCellDelegate {

    @IBOutlet weak var collectionViewSource: UICollectionView!
    @IBOutlet weak var collectionViewDestination: UICollectionView!
    @IBOutlet weak var cancel: UIBarButtonItem!
    @IBOutlet weak var save: UIBarButtonItem!
    @IBOutlet weak var add: UIButton!
    @IBOutlet weak var transferDown: UIButton!
    @IBOutlet weak var labelTitlePDFzone: UILabel!
    @IBOutlet weak var segmentControlFilter: UISegmentedControl!

    public var serverUrl: String?
    public var controller: NCMainTabBarController!

    // Data Source for collectionViewSource
    internal var itemsSource: [String] = []

    // Data Source for collectionViewDestination
    internal var imagesDestination: [UIImage] = []
    internal var itemsDestination: [String] = []

    internal let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    internal let utilityFileSystem = NCUtilityFileSystem()
    internal let utility = NCUtility()
    internal let database = NCManageDatabase.shared
    internal var filter: NCGlobal.TypeFilterScanDocument = NCKeychain().typeFilterScanDocument
    internal var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    private var tipView: EasyTipView?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .secondarySystemGroupedBackground
        navigationController?.navigationBar.tintColor = NCBrandColor.shared.iconImageColor
        navigationItem.title = NSLocalizedString("_scanned_images_", comment: "")

        collectionViewSource.dragInteractionEnabled = true
        collectionViewSource.dragDelegate = self
        collectionViewSource.dropDelegate = self
        collectionViewSource.backgroundColor = .secondarySystemGroupedBackground

        collectionViewDestination.dragInteractionEnabled = true
        collectionViewDestination.dropDelegate = self
        collectionViewDestination.dragDelegate = self
        collectionViewDestination.reorderingCadence = .fast // default value - .immediate
        collectionViewDestination.backgroundColor = .secondarySystemGroupedBackground

        cancel.title = NSLocalizedString("_cancel_", comment: "")
        save.title = NSLocalizedString("_save_", comment: "")

        labelTitlePDFzone.text = NSLocalizedString("_scan_label_document_zone_", comment: "")
        labelTitlePDFzone.backgroundColor = .systemGray6
        labelTitlePDFzone.textColor = NCBrandColor.shared.textColor

        segmentControlFilter.setTitle(NSLocalizedString("_filter_document_", comment: ""), forSegmentAt: 0)
        segmentControlFilter.setTitle(NSLocalizedString("_filter_original_", comment: ""), forSegmentAt: 1)
        if filter == .document {
            segmentControlFilter.selectedSegmentIndex = 0
        } else if filter == .original {
            segmentControlFilter.selectedSegmentIndex = 1
        }

        add.setImage(utility.loadImage(named: "plus", colors: [NCBrandColor.shared.iconImageColor]), for: .normal)
        transferDown.setImage(utility.loadImage(named: "arrow.down", colors: [NCBrandColor.shared.iconImageColor]), for: .normal)

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(recognizer:)))
        collectionViewSource.addGestureRecognizer(longPressRecognizer)
        let longPressRecognizerPlus = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(recognizer:)))
        add.addGestureRecognizer(longPressRecognizerPlus)

        collectionViewSource.reloadData()
        collectionViewDestination.reloadData()

        NotificationCenter.default.addObserver(self, selector: #selector(dismiss(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDismissScanDocument), object: nil)

        loadImage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showTip()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissTip()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        dismissTip()
    }

    // MARK: -

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        add.setImage(utility.loadImage(named: "plus", colors: [NCBrandColor.shared.iconImageColor]), for: .normal)
        transferDown.setImage(utility.loadImage(named: "arrow.down", colors: [NCBrandColor.shared.iconImageColor]), for: .normal)
    }

    override var canBecomeFirstResponder: Bool { return true }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(pasteImage) {
            return true
        }
        return false
    }

    @objc func dismiss(_ notification: NSNotification) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func cancelAction(sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func saveAction(sender: UIBarButtonItem) {
        guard !imagesDestination.isEmpty else { return }
        var images: [UIImage] = []
        for image in imagesDestination {
            images.append(filter(image: image)!)
        }
        let serverUrl = self.serverUrl ?? utilityFileSystem.getHomeServer(session: session)
        let model = NCUploadScanDocument(images: images, serverUrl: serverUrl, controller: controller)
        let details = UploadScanDocumentView(model: model)
        let vc = UIHostingController(rootView: details)

        vc.title = NSLocalizedString("_save_", comment: "")

        self.navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func add(sender: UIButton) {
        // TIP
        dismissTip()
        NCDocumentCamera.shared.openScannerDocument(viewController: self)
    }

    @IBAction func transferDown(sender: UIButton) {
        for fileName in itemsSource where !itemsDestination.contains(fileName) {
            let fileNamePathAt = utilityFileSystem.directoryScan + "/" + fileName
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: fileNamePathAt)), let image = UIImage(data: data) else { return }

            imagesDestination.append(image)
            itemsDestination.append(fileName)
        }
        collectionViewDestination.reloadData()
    }

    @IBAction func indexChanged(_ sender: AnyObject) {
        switch segmentControlFilter.selectedSegmentIndex {
        case 0:
            filter = .document
        case 1:
            filter = .original
        default:
            break
        }

        NCKeychain().typeFilterScanDocument = filter
        collectionViewDestination.reloadData()
    }

    func loadImage() {
        itemsSource.removeAll()
        do {
            let atPath = utilityFileSystem.directoryScan
            let directoryContents = try FileManager.default.contentsOfDirectory(atPath: atPath)
            for fileName in directoryContents where fileName.first != "." {
                itemsSource.append(fileName)
            }
        } catch {
            print(error.localizedDescription)
        }

        itemsSource = itemsSource.sorted()

        collectionViewSource.reloadData()
    }

    func filter(image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }

        if filter == .document {
            let imageFilter = ciImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0, "inputContrast": 1.1]).applyingFilter("CIDocumentEnhancer", parameters: ["inputAmount": 5])
            let context: CIContext = CIContext(options: nil)
            let cgImage: CGImage = context.createCGImage(imageFilter, from: imageFilter.extent)!
            let image: UIImage = UIImage(cgImage: cgImage)
            return image
        }

        return image
    }

    // destinationIndexPath: indexpath of the collection view where the user drops the element
    // collectionView: collectionView in which reordering needs to be done.

    func reorderItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView) {
        let items = coordinator.items

        if items.count == 1, let item = items.first, let sourceIndexPath = item.sourceIndexPath {
            var dIndexPath = destinationIndexPath

            if dIndexPath.row >= collectionView.numberOfItems(inSection: 0) {
                dIndexPath.row = collectionView.numberOfItems(inSection: 0) - 1
            }

            collectionView.performBatchUpdates({
                if collectionView === collectionViewDestination {
                    imagesDestination.remove(at: sourceIndexPath.row)
                    imagesDestination.insert((item.dragItem.localObject as? UIImage)!, at: dIndexPath.row)
                    let fileName = itemsDestination[sourceIndexPath.row]
                    itemsDestination.remove(at: sourceIndexPath.row)
                    itemsDestination.insert(fileName, at: dIndexPath.row)
                } else {
                    itemsSource.remove(at: sourceIndexPath.row)
                    itemsSource.insert((item.dragItem.localObject as? String)!, at: dIndexPath.row)
                }
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [dIndexPath])
            })

            coordinator.drop(items.first!.dragItem, toItemAt: dIndexPath)
        }
    }

    func copyItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView) {
        collectionView.performBatchUpdates({
            var indexPaths: [IndexPath] = []

            for (index, item) in coordinator.items.enumerated() {
                let indexPath = IndexPath(row: destinationIndexPath.row + index, section: destinationIndexPath.section)

                if collectionView === collectionViewDestination {
                    let fileName = (item.dragItem.localObject as? String)!
                    let fileNamePathAt = utilityFileSystem.directoryScan + "/" + fileName
                    guard let data = try? Data(contentsOf: URL(fileURLWithPath: fileNamePathAt)), let image = UIImage(data: data) else { return }

                    imagesDestination.insert(image, at: indexPath.row)
                    itemsDestination.insert(fileName, at: indexPath.row)
                } else {
                    // NOT PERMITTED
                    return
                }
                indexPaths.append(indexPath)
            }
            collectionView.insertItems(at: indexPaths)
        })
    }

    @objc func handleLongPressGesture(recognizer: UIGestureRecognizer) {
        if recognizer.state == UIGestureRecognizer.State.began {
            self.becomeFirstResponder()
            let pasteboard = UIPasteboard.general
            if let recognizerView = recognizer.view, let recognizerSuperView = recognizerView.superview, pasteboard.hasImages {
                UIMenuController.shared.menuItems = [UIMenuItem(title: "Paste", action: #selector(pasteImage))]
                UIMenuController.shared.showMenu(from: recognizerSuperView, rect: recognizerView.frame)
            }
            // TIP
            dismissTip()
        }
    }

    @objc func pasteImage() {
        let pasteboard = UIPasteboard.general
        if pasteboard.hasImages {
            guard let image = pasteboard.image?.fixedOrientation() else { return }
            let fileName = utilityFileSystem.createFileName("scan.png", fileDate: Date(), fileType: PHAssetMediaType.image, notUseMask: true)
            let fileNamePath = utilityFileSystem.directoryScan + "/" + fileName

            do {
                try image.pngData()?.write(to: NSURL.fileURL(withPath: fileNamePath), options: .atomic)
            } catch {
                return
            }

            loadImage()
        }
    }

    func delete(with imageIndex: Int, sender: Any) {
        imagesDestination.remove(at: imageIndex)
        itemsDestination.remove(at: imageIndex)
        collectionViewDestination.reloadData()
    }

    func imageTapped(with index: Int, sender: Any) {
        guard index < self.itemsSource.count else {
            return collectionViewSource.reloadData()
        }
        let fileName = self.itemsSource[index]
        let fileNamePath = utilityFileSystem.directoryScan + "/" + fileName
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: fileNamePath)), let image = UIImage(data: data) else {
            return collectionViewSource.reloadData()
        }

        imagesDestination.append(image)
        itemsDestination.append(fileName)
        collectionViewDestination.reloadData()
    }
}

extension NCScan: EasyTipViewDelegate {
    func showTip() {
        if !self.database.tipExists(NCGlobal.shared.tipScanAddImage) {
            var preferences = EasyTipView.Preferences()
            preferences.drawing.foregroundColor = .white
            preferences.drawing.backgroundColor = .lightGray
            preferences.drawing.textAlignment = .left
            preferences.drawing.arrowPosition = .left
            preferences.drawing.cornerRadius = 10

            preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: 100)
            preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -100)
            preferences.animating.showInitialAlpha = 0
            preferences.animating.showDuration = 1.5
            preferences.animating.dismissDuration = 1.5

            if tipView == nil {
                tipView = EasyTipView(text: NSLocalizedString("_tip_addcopyimage_", comment: ""), preferences: preferences, delegate: self)
                tipView?.show(forView: add, withinSuperview: self.view)
            }
        }
    }

    func easyTipViewDidTap(_ tipView: EasyTipView) {
        self.database.addTip(NCGlobal.shared.tipScanAddImage)
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) { }

    func dismissTip() {
        if !self.database.tipExists(NCGlobal.shared.tipScanAddImage) {
            self.database.addTip(NCGlobal.shared.tipScanAddImage)
        }
        tipView?.dismiss()
        tipView = nil
    }
}

extension NCScan: NCViewerQuickLookDelegate {
    func dismissQuickLook(fileNameSource: String, hasChangesQuickLook: Bool) {
        let fileNameAtPath = NSTemporaryDirectory() + fileNameSource
        let fileNameToPath = utilityFileSystem.directoryScan + "/" + fileNameSource
        utilityFileSystem.copyFile(atPath: fileNameAtPath, toPath: fileNameToPath)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: fileNameToPath)), let image = UIImage(data: data) else { return }
        var index = 0
        for fileName in self.itemsDestination {
            if fileName == fileNameSource {
                imagesDestination[index] = image
                index += 1
                break
            }
        }
        collectionViewSource.reloadData()
        collectionViewDestination.reloadData()
    }
}
