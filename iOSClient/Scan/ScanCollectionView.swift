//
//  ScanCollectionView.swift
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 21/08/18.
//  Copyright (c) 2018 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

@available(iOS 11, *)

class DragDropViewController: UIViewController {
    
    //Data Source for collectionViewSource
    private var itemsSource = [String]()
    
    //Data Source for collectionViewDestination
    private var imagesDestination = [UIImage]()

    //AppDelegate
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    //MARK: Outlets
    @IBOutlet weak var collectionViewSource: UICollectionView!
    @IBOutlet weak var collectionViewDestination: UICollectionView!
    @IBOutlet weak var cancel: UIBarButtonItem!
    @IBOutlet weak var save: UIBarButtonItem!
    @IBOutlet weak var add: UIButton!
    @IBOutlet weak var labelTitlePDFzone: UILabel!
    @IBOutlet weak var segmentControlFilter: UISegmentedControl!

    // filter
    enum typeFilter {
        case original
        case grayScale
        case bn
    }
    private var filter: typeFilter = typeFilter.grayScale
    
    //MARK: View Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.collectionViewSource.dragInteractionEnabled = true
        self.collectionViewSource.dragDelegate = self
        self.collectionViewSource.dropDelegate = self
        
        self.collectionViewDestination.dragInteractionEnabled = true
        self.collectionViewDestination.dropDelegate = self
        self.collectionViewDestination.dragDelegate = self
        self.collectionViewDestination.reorderingCadence = .fast //default value - .immediate
        
        self.navigationItem.title = NSLocalizedString("_scanned_images_", comment: "")
        cancel.title = NSLocalizedString("_cancel_", comment: "")
        save.title = NSLocalizedString("_save_", comment: "")
        labelTitlePDFzone.text = NSLocalizedString("_scan_label_PDF_zone_", comment: "")
        segmentControlFilter.setTitle(NSLocalizedString("_filter_grayscale_", comment: ""), forSegmentAt: 0)
        segmentControlFilter.setTitle(NSLocalizedString("_filter_bn_", comment: ""), forSegmentAt: 1)
        segmentControlFilter.setTitle(NSLocalizedString("_filter_original_", comment: ""), forSegmentAt: 2)

        add.setImage(CCGraphics.changeThemingColorImage(UIImage(named: "add"), multiplier:2, color: NCBrandColor.sharedInstance.brand), for: .normal)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        appDelegate.aspectNavigationControllerBar(self.navigationController?.navigationBar, online: appDelegate.reachability.isReachable(), hidden: false)
        
        labelTitlePDFzone.textColor = NCBrandColor.sharedInstance.brandText
        labelTitlePDFzone.backgroundColor = NCBrandColor.sharedInstance.brand
        
        segmentControlFilter.tintColor = NCBrandColor.sharedInstance.brand
        
        // Save button
        if imagesDestination.count == 0 {
            save.isEnabled = false
        } else {
            save.isEnabled = true
        }
        
        loadImage(atPath: CCUtility.getDirectoryScan(), items: &itemsSource)
        
        self.collectionViewSource.reloadData()
    }
    
    //MARK: Button Action

    @IBAction func cancelAction(sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func saveAction(sender: UIBarButtonItem) {
        
        if imagesDestination.count > 0 {
            
            var images = [UIImage]()

            for image in imagesDestination {
                images.append(filter(image: image)!)
            }
            
            let formViewController = CreateFormUploadScanDocument.init(serverUrl: appDelegate.activeMain.serverUrl, arrayImages: images)
            self.navigationController?.pushViewController(formViewController, animated: true)
        }
    }
    
    @IBAction func add(sender: UIButton) {
        
        NCCreateScanDocument.sharedInstance.openScannerDocument(viewController: self, openScan: false)
    }
    
    @IBAction func indexChanged(_ sender: AnyObject) {
        
        switch segmentControlFilter.selectedSegmentIndex
        {
        case 0:
            // Grayscale
            filter = typeFilter.grayScale
        case 1:
            // Original
            filter = typeFilter.bn
        case 2:
            // Original
            filter = typeFilter.original
        default:
            break
        }
        
        self.collectionViewDestination.reloadData()
    }
    
    //MARK: Private Methods
    
    private func loadImage(atPath: String, items: inout [String]) {
        
        items.removeAll()

        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(atPath: atPath)
            for fileName in directoryContents {
                if fileName.first != "." {
                    items.append(fileName)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
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
                
                if collectionView === self.collectionViewDestination {
                    
                    self.imagesDestination.remove(at: sourceIndexPath.row)
                    self.imagesDestination.insert(item.dragItem.localObject as! UIImage, at: dIndexPath.row)
                    
                } else {
                    
                    self.itemsSource.remove(at: sourceIndexPath.row)
                    self.itemsSource.insert(item.dragItem.localObject as! String, at: dIndexPath.row)
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
            
            var indexPaths = [IndexPath]()
            
            for (index, item) in coordinator.items.enumerated() {
                
                let indexPath = IndexPath(row: destinationIndexPath.row + index, section: destinationIndexPath.section)
                
                if collectionView === self.collectionViewDestination {
                    
                    let fileName = item.dragItem.localObject as! NSString
                    let fileNamePathAt = CCUtility.getDirectoryScan() + "/" + (fileName as String)
                    
                    guard let data = try? Data(contentsOf: fileNamePathAt.url) else {
                        return
                    }
                    guard let image =  UIImage(data: data) else {
                        return
                    }
                   
                    self.imagesDestination.insert(image, at: indexPath.row)
                    
                } else {
                    
                    // NOT PERMITTED
                    return
                }
                
                indexPaths.append(indexPath)
            }
            
            collectionView.insertItems(at: indexPaths)
        })
    }
}

// MARK: - UICollectionViewDataSource Methods

@available(iOS 11, *)

extension DragDropViewController : UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return collectionView == self.collectionViewSource ? self.itemsSource.count : self.imagesDestination.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if collectionView == self.collectionViewSource {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell1", for: indexPath) as! ScanCell
            
            let fileNamePath = CCUtility.getDirectoryScan() + "/" + self.itemsSource[indexPath.row]
            
            guard let data = try? Data(contentsOf: fileNamePath.url) else {
                return cell
            }
            
            cell.customImageView?.image = UIImage(data: data)
//            cell.delete.setImage(CCGraphics.changeThemingColorImage(UIImage(named: "no_red"), multiplier:2, color: NCBrandColor.sharedInstance.icon).withRenderingMode(.alwaysOriginal), for: .normal)
            cell.delete.addTarget(self, action: #selector(deleteSource(_:)), for: .touchUpInside)

            return cell
            
        } else {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell2", for: indexPath) as! ScanCell
            
            let image = self.imagesDestination[indexPath.row]
            
            cell.customImageView?.image = self.filter(image: image)
            cell.customLabel.text = NSLocalizedString("_scan_document_pdf_page_", comment: "") + " " + "\(indexPath.row+1)"
//            cell.delete.setImage(CCGraphics.changeThemingColorImage(UIImage(named: "no_red"), multiplier:2, color: NCBrandColor.sharedInstance.icon).withRenderingMode(.alwaysOriginal), for: .normal)
            cell.delete.addTarget(self, action: #selector(deleteDestination(_:)), for: .touchUpInside)
            
            return cell
        }
    }
    
    @objc func deleteSource(_ sender: UIButton) {
        
        let buttonPosition:CGPoint =  sender.convert(.zero, to: self.collectionViewSource)
        let indexPath:IndexPath = self.collectionViewSource.indexPathForItem(at: buttonPosition)!
        
        let fileNameAtPath = CCUtility.getDirectoryScan() + "/" + self.itemsSource[indexPath.row]
        CCUtility.removeFile(atPath: fileNameAtPath)
        self.itemsSource.remove(at: indexPath.row)
        
        self.collectionViewSource.reloadData()
    }
    
    @objc func deleteDestination(_ sender:UIButton) {
        
        let buttonPosition:CGPoint =  sender.convert(.zero, to: self.collectionViewDestination)
        let indexPath:IndexPath = self.collectionViewDestination.indexPathForItem(at: buttonPosition)!
        
        self.imagesDestination.remove(at: indexPath.row)
        
        self.collectionViewDestination.reloadData()
        
        // Save button
        if imagesDestination.count == 0 {
            save.isEnabled = false
        } else {
            save.isEnabled = true
        }
    }
}

// MARK: - UICollectionViewDragDelegate Methods

@available(iOS 11, *)

extension DragDropViewController : UICollectionViewDragDelegate
{
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        
        if collectionView == self.collectionViewSource {
            let item = self.itemsSource[indexPath.row]
            let itemProvider = NSItemProvider(object: item as NSString)
            let dragItem = UIDragItem(itemProvider: itemProvider)

            dragItem.localObject = item

            return [dragItem]

        } else {
            let item = self.imagesDestination[indexPath.row]
            let itemProvider = NSItemProvider(object: item as UIImage)
            let dragItem = UIDragItem(itemProvider: itemProvider)

            dragItem.localObject = item
            
            return [dragItem]
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        
        if collectionView == self.collectionViewSource {
            let item = self.itemsSource[indexPath.row]
            let itemProvider = NSItemProvider(object: item as NSString)
            let dragItem = UIDragItem(itemProvider: itemProvider)
            
            dragItem.localObject = item
            
            return [dragItem]
            
        } else {
            let item = self.imagesDestination[indexPath.row]
            let itemProvider = NSItemProvider(object: item as UIImage)
            let dragItem = UIDragItem(itemProvider: itemProvider)
            
            dragItem.localObject = item
            
            return [dragItem]
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        
        let previewParameters = UIDragPreviewParameters()
        if collectionView == self.collectionViewSource {
            previewParameters.visiblePath = UIBezierPath(rect: CGRect(x: 20, y: 20, width: 100, height: 100))
        } else {
            previewParameters.visiblePath = UIBezierPath(rect: CGRect(x: 20, y: 20, width: 80, height: 80))
        }
         
        return previewParameters
    }
}

// MARK: - UICollectionViewDropDelegate Methods

@available(iOS 11, *)

extension DragDropViewController : UICollectionViewDropDelegate {
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        
        return true //session.canLoadObjects(ofClass: NSString.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        
        if collectionView == self.collectionViewSource {
            
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
        
        if let indexPath = coordinator.destinationIndexPath {
        
            destinationIndexPath = indexPath
        
        } else {
        
            // Get last index path of table view.
            let section = collectionView.numberOfSections - 1
            let row = collectionView.numberOfItems(inSection: section)
            
            destinationIndexPath = IndexPath(row: row, section: section)
        }
        
        switch coordinator.proposal.operation {
            
        case .move:
            self.reorderItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
            break
            
        case .copy:
            self.copyItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
            break
            
        default:
            return
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        
        self.collectionViewDestination.reloadData()
        
        // Save button
        if imagesDestination.count == 0 {
            save.isEnabled = false
        } else {
            save.isEnabled = true
        }
    }
}

