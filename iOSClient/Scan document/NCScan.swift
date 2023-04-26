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

class NCScan: UIViewController, NCScanCellCellDelegate {

    @IBOutlet weak var collectionViewSource: UICollectionView!
    @IBOutlet weak var collectionViewDestination: UICollectionView!
    @IBOutlet weak var cancel: UIBarButtonItem!
    @IBOutlet weak var save: UIBarButtonItem!
    @IBOutlet weak var add: UIButton!
    @IBOutlet weak var transferDown: UIButton!
    @IBOutlet weak var labelTitlePDFzone: UILabel!
    @IBOutlet weak var segmentControlFilter: UISegmentedControl!

    // Data Source for collectionViewSource
    internal var itemsSource: [String] = []

    // Data Source for collectionViewDestination
    internal var imagesDestination: [UIImage] = []
    internal var itemsDestination: [String] = []

    internal let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    private var tipView: EasyTipView?

    enum TypeFilter {
        case original
        case grayScale
        case bn
    }
    internal var filter: TypeFilter = TypeFilter.original

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .secondarySystemGroupedBackground
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
        labelTitlePDFzone.textColor = .label

        segmentControlFilter.setTitle(NSLocalizedString("_filter_original_", comment: ""), forSegmentAt: 0)
        segmentControlFilter.setTitle(NSLocalizedString("_filter_grayscale_", comment: ""), forSegmentAt: 1)
        segmentControlFilter.setTitle(NSLocalizedString("_filter_bn_", comment: ""), forSegmentAt: 2)

        add.setImage(UIImage(named: "plus")?.image(color: .label, size: 25), for: .normal)
        transferDown.setImage(UIImage(named: "transferDown")?.image(color: .label, size: 25), for: .normal)

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(recognizer:)))
        collectionViewSource.addGestureRecognizer(longPressRecognizer)
        let longPressRecognizerPlus = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(recognizer:)))
        add.addGestureRecognizer(longPressRecognizerPlus)

        // TIP
        var preferences = EasyTipView.Preferences()
        preferences.drawing.foregroundColor = .white
        preferences.drawing.backgroundColor = NCBrandColor.shared.nextcloud
        preferences.drawing.textAlignment = .left
        preferences.drawing.arrowPosition = .left
        preferences.drawing.cornerRadius = 10

        preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: 100)
        preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -100)
        preferences.animating.showInitialAlpha = 0
        preferences.animating.showDuration = 1.5
        preferences.animating.dismissDuration = 1.5

        tipView = EasyTipView(text: NSLocalizedString("_tip_addcopyimage_", comment: ""), preferences: preferences, delegate: self)

        collectionViewSource.reloadData()
        collectionViewDestination.reloadData()

        NotificationCenter.default.addObserver(self, selector: #selector(dismiss(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDismissScanDocument), object: nil)

        loadImage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        showTip()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        self.tipView?.dismiss()
        coordinator.animate(alongsideTransition: nil) { _ in
            self.showTip()
        }
    }

    // MARK: - Tip

    func showTip() {

        if !NCManageDatabase.shared.tipExists(NCGlobal.shared.tipNCScanAddImage) {
            self.tipView?.show(forView: add, withinSuperview: self.view)
        }
    }

    // MARK: -

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        add.setImage(UIImage(named: "plus")?.image(color: .label, size: 25), for: .normal)
        transferDown.setImage(UIImage(named: "transferDown")?.image(color: .label, size: 25), for: .normal)
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

        if !imagesDestination.isEmpty {

            var images: [UIImage] = []
            let serverUrl = appDelegate.activeServerUrl

            for image in imagesDestination {
                images.append(filter(image: image)!)
            }

            let  vc = NCHostingUploadScanDocumentView().makeShipDetailsUI(images: images, userBaseUrl: appDelegate, serverUrl: serverUrl)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func add(sender: UIButton) {

        // TIP
        dismissTip()

        NCDocumentCamera.shared.openScannerDocument(viewController: self)
    }

    @IBAction func transferDown(sender: UIButton) {

        for fileName in itemsSource where !itemsDestination.contains(fileName) {

            let fileNamePathAt = CCUtility.getDirectoryScan() + "/" + fileName
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: fileNamePathAt)), let image = UIImage(data: data) else { return }

            imagesDestination.append(image)
            itemsDestination.append(fileName)
        }

        // Save button
        if imagesDestination.isEmpty {
            save.isEnabled = false
        } else {
            save.isEnabled = true
        }

        collectionViewDestination.reloadData()
    }

    @IBAction func indexChanged(_ sender: AnyObject) {

        switch segmentControlFilter.selectedSegmentIndex {
        case 0:
            filter = .original
        case 1:
            filter = .grayScale
        case 2:
            filter = .bn
        default:
            break
        }

        collectionViewDestination.reloadData()
    }

    func loadImage() {

        itemsSource.removeAll()

        do {
            let atPath = CCUtility.getDirectoryScan()!
            let directoryContents = try FileManager.default.contentsOfDirectory(atPath: atPath)
            for fileName in directoryContents where fileName.first != "." {
                itemsSource.append(fileName)
            }
        } catch {
            print(error.localizedDescription)
        }

        itemsSource = itemsSource.sorted()

        collectionViewSource.reloadData()

        // Save button
        if imagesDestination.isEmpty {
            save.isEnabled = false
        } else {
            save.isEnabled = true
        }
    }

    func filter(image: UIImage) -> UIImage? {

        var inputContrast: Double = 0

        if filter == .original {
            return image
        }

        if filter == .grayScale {
            inputContrast = 1
        }

        if filter == .bn {
            inputContrast = 4
        }

        let ciImage = CIImage(image: image)!
        let imageFilter = ciImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0, "inputContrast": inputContrast])

        let context: CIContext = CIContext(options: nil)
        let cgImage: CGImage = context.createCGImage(imageFilter, from: imageFilter.extent)!
        let image: UIImage = UIImage(cgImage: cgImage)
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
                    let fileNamePathAt = CCUtility.getDirectoryScan() + "/" + fileName

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

            let fileName = CCUtility.createFileName("scan.png", fileDate: Date(),
                                                    fileType: PHAssetMediaType.image,
                                                    keyFileName: NCGlobal.shared.keyFileNameMask,
                                                    keyFileNameType: NCGlobal.shared.keyFileNameType,
                                                    keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal,
                                                    forcedNewFileName: true)!
            let fileNamePath = CCUtility.getDirectoryScan() + "/" + fileName

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

        // Save button
        if imagesDestination.isEmpty {
            save.isEnabled = false
        } else {
            save.isEnabled = true
        }

        collectionViewDestination.reloadData()
    }

    func rotate(with imageIndex: Int, sender: Any) {

        let indexPath = IndexPath(row: imageIndex, section: 0)
        if let cell = collectionViewDestination.cellForItem(at: indexPath) as? NCScanCell {

            var image = imagesDestination[imageIndex]
            image = image.rotate(radians: .pi / 2)!
            imagesDestination[imageIndex] = image
            cell.customImageView.image = image
        }
    }
}

extension NCScan: EasyTipViewDelegate {

    // TIP
    func easyTipViewDidTap(_ tipView: EasyTipView) {
        NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCScanAddImage)
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) { }

    func dismissTip() {
        NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCScanAddImage)
        self.tipView?.dismiss()
    }
}
