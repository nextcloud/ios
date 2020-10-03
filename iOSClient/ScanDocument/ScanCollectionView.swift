//
//  ScanCollectionView.swift
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

class DragDropViewController: UIViewController {
    
    //Data Source for collectionViewSource
    private var itemsSource: [String] = []
    
    //Data Source for collectionViewDestination
    private var imagesDestination: [UIImage] = []
    private var itemsDestination: [String] = []
    
    //AppDelegate
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    //MARK: Outlets
    @IBOutlet weak var collectionViewSource: UICollectionView!
    @IBOutlet weak var collectionViewDestination: UICollectionView!
    @IBOutlet weak var cancel: UIBarButtonItem!
    @IBOutlet weak var save: UIBarButtonItem!
    @IBOutlet weak var add: UIButton!
    @IBOutlet weak var transferDown: UIButton!
    @IBOutlet weak var labelTitlePDFzone: UILabel!
    @IBOutlet weak var segmentControlFilter: UISegmentedControl!

    // filter
    enum typeFilter {
        case original
        case grayScale
        case bn
    }
    private var filter: typeFilter = typeFilter.original
    
    override var canBecomeFirstResponder: Bool { return true }
    
    //MARK: View Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionViewSource.dragInteractionEnabled = true
        collectionViewSource.dragDelegate = self
        collectionViewSource.dropDelegate = self
        
        collectionViewDestination.dragInteractionEnabled = true
        collectionViewDestination.dropDelegate = self
        collectionViewDestination.dragDelegate = self
        collectionViewDestination.reorderingCadence = .fast //default value - .immediate
        
        self.navigationItem.title = NSLocalizedString("_scanned_images_", comment: "")
        cancel.title = NSLocalizedString("_cancel_", comment: "")
        save.title = NSLocalizedString("_save_", comment: "")
        labelTitlePDFzone.text = NSLocalizedString("_scan_label_document_zone_", comment: "")
        
        segmentControlFilter.setTitle(NSLocalizedString("_filter_original_", comment: ""), forSegmentAt: 0)
        segmentControlFilter.setTitle(NSLocalizedString("_filter_grayscale_", comment: ""), forSegmentAt: 1)
        segmentControlFilter.setTitle(NSLocalizedString("_filter_bn_", comment: ""), forSegmentAt: 2)

        add.setImage(CCGraphics.changeThemingColorImage(UIImage(named: "add"), multiplier:2, color: NCBrandColor.sharedInstance.brandElement), for: .normal)
        transferDown.setImage(CCGraphics.changeThemingColorImage(UIImage(named: "transferDown"), multiplier:2, color: NCBrandColor.sharedInstance.brandElement), for: .normal)
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(recognizer:)))
        add.addGestureRecognizer(longPressRecognizer)
        
        // changeTheming
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        changeTheming()
        
        loadImage()
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: nil, form: true)
        
        collectionViewSource.backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        collectionViewDestination.backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        
        labelTitlePDFzone.textColor = NCBrandColor.sharedInstance.textView
        if #available(iOS 13.0, *) {
            labelTitlePDFzone.backgroundColor = .systemBackground
        } else {
            labelTitlePDFzone.backgroundColor = .systemGray
        }
    }
    
    //MARK: Button Action

    @IBAction func cancelAction(sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func saveAction(sender: UIBarButtonItem) {
        
        if imagesDestination.count > 0 {
            
            var images: [UIImage] = []
            var serverUrl = appDelegate.activeServerUrl!

            for image in imagesDestination {
                images.append(filter(image: image)!)
            }
            
            if let directory = CCUtility.getDirectoryScanDocuments() {
                serverUrl = directory
            }
            
            let formViewController = NCCreateFormUploadScanDocument.init(serverUrl: serverUrl, arrayImages: images)
            self.navigationController?.pushViewController(formViewController, animated: true)
        }
    }
    
    @IBAction func add(sender: UIButton) {
        
        NCCreateScanDocument.sharedInstance.openScannerDocument(viewController: self)
    }
    
    @IBAction func transferDown(sender: UIButton) {
     
        for fileName in itemsSource {
            
            if !itemsDestination.contains(fileName) {
                
                let fileNamePathAt = CCUtility.getDirectoryScan() + "/" + fileName
                
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: fileNamePathAt)) else { return }
                guard let image = UIImage(data: data) else { return }
                
                imagesDestination.append(image)
                itemsDestination.append(fileName)
            }
        }
        
        // Save button
        if imagesDestination.count == 0 {
            save.isEnabled = false
        } else {
            save.isEnabled = true
        }
        
        collectionViewDestination.reloadData()
    }
    
    @IBAction func indexChanged(_ sender: AnyObject) {
        
        switch segmentControlFilter.selectedSegmentIndex
        {
        case 0:
            filter = typeFilter.original
        case 1:
            filter = typeFilter.grayScale
        case 2:
            filter = typeFilter.bn
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
            for fileName in directoryContents {
                if fileName.first != "." {
                    itemsSource.append(fileName)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        
        itemsSource = itemsSource.sorted()
        
        collectionViewSource.reloadData()
        
        // Save button
        if imagesDestination.count == 0 {
            save.isEnabled = false
        } else {
            save.isEnabled = true
        }
    }
    
    //MARK: Private Methods
    
    func filter(image: UIImage) -> UIImage? {
        
        var inputContrast: Double = 0
        
        if filter == typeFilter.original {
            return image
        }
        
        if filter == typeFilter.grayScale {
            inputContrast = 1
        }
        
        if filter == typeFilter.bn {
            inputContrast = 4
        }
        
        let ciImage = CIImage(image: image)!
        let imageFilter = ciImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0, "inputContrast": inputContrast])
        
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(imageFilter, from: imageFilter.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
    /// This method moves a cell from source indexPath to destination indexPath within the same collection view. It works for only 1 item. If multiple items selected, no reordering happens.
    ///
    /// - Parameters:
    ///   - coordinator: coordinator obtained from performDropWith: UICollectionViewDropDelegate method
    ///   - destinationIndexPath: indexpath of the collection view where the user drops the element
    ///   - collectionView: collectionView in which reordering needs to be done.
    
    private func reorderItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView) {
        
        let items = coordinator.items
        
        if items.count == 1, let item = items.first, let sourceIndexPath = item.sourceIndexPath {
            
            var dIndexPath = destinationIndexPath
            
            if dIndexPath.row >= collectionView.numberOfItems(inSection: 0) {
                dIndexPath.row = collectionView.numberOfItems(inSection: 0) - 1
            }
            
            collectionView.performBatchUpdates({
                
                if collectionView === collectionViewDestination {
                    
                    imagesDestination.remove(at: sourceIndexPath.row)
                    imagesDestination.insert(item.dragItem.localObject as! UIImage, at: dIndexPath.row)
                    
                    let fileName = itemsDestination[sourceIndexPath.row]
                    itemsDestination.remove(at: sourceIndexPath.row)
                    itemsDestination.insert(fileName, at: dIndexPath.row)
                
                } else {
                    
                    itemsSource.remove(at: sourceIndexPath.row)
                    itemsSource.insert(item.dragItem.localObject as! String, at: dIndexPath.row)
                }
                
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [dIndexPath])
            })
            
            coordinator.drop(items.first!.dragItem, toItemAt: dIndexPath)
        }
    }
    
    /// This method copies a cell from source indexPath in 1st collection view to destination indexPath in 2nd collection view. It works for multiple items.
    ///
    /// - Parameters:
    ///   - coordinator: coordinator obtained from performDropWith: UICollectionViewDropDelegate method
    ///   - destinationIndexPath: indexpath of the collection view where the user drops the element
    ///   - collectionView: collectionView in which reordering needs to be done.
    
    private func copyItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView)
    {
        collectionView.performBatchUpdates({
            
            var indexPaths: [IndexPath] = []
            
            for (index, item) in coordinator.items.enumerated() {
                
                let indexPath = IndexPath(row: destinationIndexPath.row + index, section: destinationIndexPath.section)
                
                if collectionView === collectionViewDestination {
                    
                    let fileName = item.dragItem.localObject as! String
                    let fileNamePathAt = CCUtility.getDirectoryScan() + "/" + fileName
                    
                    guard let data = try? Data(contentsOf: URL(fileURLWithPath: fileNamePathAt)) else {
                        return
                    }
                    guard let image =  UIImage(data: data) else {
                        return
                    }
                   
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
    
    // MARK: - UIGestureRecognizerv - Paste
    
    @objc func handleLongPressGesture(recognizer: UIGestureRecognizer) {
        
        if recognizer.state == UIGestureRecognizer.State.began {
        
            self.becomeFirstResponder()
            
            let pasteboard = UIPasteboard.general
            
            if let recognizerView = recognizer.view, let recognizerSuperView = recognizerView.superview, pasteboard.hasImages {
                
                UIMenuController.shared.menuItems = [UIMenuItem(title: "Paste", action: #selector(pasteImage))]
                UIMenuController.shared.setTargetRect(recognizerView.frame, in: recognizerSuperView)
                UIMenuController.shared.setMenuVisible(true, animated:true)
            }
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(pasteImage) {
            return true
        }
        return false
    }
    
    @objc func pasteImage() {
        
        let pasteboard = UIPasteboard.general
        
        if pasteboard.hasImages {
            
            let fileName = CCUtility.createFileName("scan.png", fileDate: Date(), fileType: PHAssetMediaType.image, keyFileName: k_keyFileNameMask, keyFileNameType: k_keyFileNameType, keyFileNameOriginal: k_keyFileNameOriginal)!
            let fileNamePath = CCUtility.getDirectoryScan() + "/" + fileName
            
            guard let image = pasteboard.image else {
                return
            }
            
            do {
                try image.pngData()?.write(to: NSURL.fileURL(withPath: fileNamePath), options: .atomic)
            } catch {
                return
            }

            loadImage()
        }
    }
}

// MARK: - UICollectionViewDataSource Methods

extension DragDropViewController : UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return collectionView == collectionViewSource ? itemsSource.count : imagesDestination.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if collectionView == collectionViewSource {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell1", for: indexPath) as! ScanCell
            
            let fileNamePath = CCUtility.getDirectoryScan() + "/" + itemsSource[indexPath.row]
            
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: fileNamePath)) else {
                return cell
            }
            
            guard var image = UIImage(data: data) else {
                return cell
            }
            
            let imageWidthInPixels = image.size.width * image.scale
            let imageHeightInPixels = image.size.height * image.scale
            
            // 72 DPI
            if imageWidthInPixels > 595 || imageHeightInPixels > 842  {
                image = CCGraphics.scale(image, to: CGSize(width: 595, height: 842), isAspectRation: true)
            }
            
            cell.customImageView?.image = image
            cell.delete.addTarget(self, action: #selector(deleteSource(_:)), for: .touchUpInside)

            return cell
            
        } else {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell2", for: indexPath) as! ScanCell
            
            var image = imagesDestination[indexPath.row]
            
            let imageWidthInPixels = image.size.width * image.scale
            let imageHeightInPixels = image.size.height * image.scale
            
            // 72 DPI 
            if imageWidthInPixels > 595 || imageHeightInPixels > 842  {
                image = CCGraphics.scale(image, to: CGSize(width: 595, height: 842), isAspectRation: true)
            }
            
            cell.customImageView?.image = self.filter(image: image)
            cell.customLabel.text = NSLocalizedString("_scan_document_pdf_page_", comment: "") + " " + "\(indexPath.row+1)"
            cell.delete.addTarget(self, action: #selector(deleteDestination(_:)), for: .touchUpInside)
            cell.rotate.addTarget(self, action: #selector(rotateDestination(_:)), for: .touchUpInside)
            
            return cell
        }
    }
    
    @objc func deleteSource(_ sender: UIButton) {
        
        let buttonPosition:CGPoint =  sender.convert(.zero, to: collectionViewSource)
        let indexPath:IndexPath = collectionViewSource.indexPathForItem(at: buttonPosition)!
        
        let fileNameAtPath = CCUtility.getDirectoryScan() + "/" + itemsSource[indexPath.row]
        CCUtility.removeFile(atPath: fileNameAtPath)
        itemsSource.remove(at: indexPath.row)
        
        collectionViewSource.reloadData()
    }
    
    @objc func deleteDestination(_ sender:UIButton) {
        
        let buttonPosition:CGPoint =  sender.convert(.zero, to: collectionViewDestination)
        let indexPath:IndexPath = collectionViewDestination.indexPathForItem(at: buttonPosition)!
        
        imagesDestination.remove(at: indexPath.row)
        itemsDestination.remove(at: indexPath.row)
        
        collectionViewDestination.reloadData()
        
        // Save button
        if imagesDestination.count == 0 {
            save.isEnabled = false
        } else {
            save.isEnabled = true
        }
    }
    
    @objc func rotateDestination(_ sender:UIButton) {
        
        let buttonPosition:CGPoint =  sender.convert(.zero, to: collectionViewDestination)
        let indexPath:IndexPath = collectionViewDestination.indexPathForItem(at: buttonPosition)!
        
        let image = imagesDestination[indexPath.row]
        imagesDestination[indexPath.row] = image.rotate(radians: .pi/2)!
        
        collectionViewDestination.reloadData()
    }
}

extension UIImage {
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, true, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

// MARK: - UICollectionViewDragDelegate Methods

extension DragDropViewController : UICollectionViewDragDelegate
{
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        
        if collectionView == collectionViewSource {
            let item = itemsSource[indexPath.row]
            let itemProvider = NSItemProvider(object: item as NSString)
            let dragItem = UIDragItem(itemProvider: itemProvider)

            dragItem.localObject = item

            return [dragItem]

        } else {
            let item = imagesDestination[indexPath.row]
            let itemProvider = NSItemProvider(object: item as UIImage)
            let dragItem = UIDragItem(itemProvider: itemProvider)

            dragItem.localObject = item
            
            return [dragItem]
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        
        if collectionView == collectionViewSource {
            let item = itemsSource[indexPath.row]
            let itemProvider = NSItemProvider(object: item as NSString)
            let dragItem = UIDragItem(itemProvider: itemProvider)
            
            dragItem.localObject = item
            
            return [dragItem]
            
        } else {
            let item = imagesDestination[indexPath.row]
            let itemProvider = NSItemProvider(object: item as UIImage)
            let dragItem = UIDragItem(itemProvider: itemProvider)
            
            dragItem.localObject = item
            
            return [dragItem]
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        
        let previewParameters = UIDragPreviewParameters()
        if collectionView == collectionViewSource {
            previewParameters.visiblePath = UIBezierPath(rect: CGRect(x: 20, y: 20, width: 100, height: 100))
        } else {
            previewParameters.visiblePath = UIBezierPath(rect: CGRect(x: 20, y: 20, width: 80, height: 80))
        }
         
        return previewParameters
    }
}

// MARK: - UICollectionViewDropDelegate Methods

extension DragDropViewController : UICollectionViewDropDelegate {
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        
        return true //session.canLoadObjects(ofClass: NSString.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        
        if collectionView == collectionViewSource {
            
            if collectionView.hasActiveDrag {
                return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            } else {
                return UICollectionViewDropProposal(operation: .forbidden)
            }
            
        } else {
            
            if collectionView.hasActiveDrag {
                return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            } else {
                return UICollectionViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        
        let destinationIndexPath: IndexPath
        
        switch coordinator.proposal.operation {
            
        case .move:
            
            if let indexPath = coordinator.destinationIndexPath {
                
                destinationIndexPath = indexPath
                
            } else {
                
                // Get last index path of table view.
                let section = collectionView.numberOfSections - 1
                let row = collectionView.numberOfItems(inSection: section)
                
                destinationIndexPath = IndexPath(row: row, section: section)
            }
            self.reorderItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
            
            break
            
        case .copy:
            
            // Get last index path of table view.
            let section = collectionView.numberOfSections - 1
            let row = collectionView.numberOfItems(inSection: section)
            
            destinationIndexPath = IndexPath(row: row, section: section)
            self.copyItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
            
            break
            
        default:
            return
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        
        collectionViewDestination.reloadData()
        
        // Save button
        if imagesDestination.count == 0 {
            save.isEnabled = false
        } else {
            save.isEnabled = true
        }
    }
}

