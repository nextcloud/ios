//

import UIKit

@available(iOS 11, *)

class DragDropViewController: UIViewController
{
    //MARK: Private Properties
    //Data Source for CollectionView-1
    private var items1 = [String]()
    
    //Data Source for CollectionView-2
    private var items2 = [String]()

    //MARK: Outlets
    @IBOutlet weak var collectionView1: UICollectionView!
    @IBOutlet weak var collectionView2: UICollectionView!
    
    //MARK: View Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //CollectionView-1 drag and drop configuration
        self.collectionView1.dragInteractionEnabled = true
        self.collectionView1.dragDelegate = self
        self.collectionView1.dropDelegate = self
        
        //CollectionView-2 drag and drop configuration
        self.collectionView2.dragInteractionEnabled = true
        self.collectionView2.dropDelegate = self
        self.collectionView2.dragDelegate = self
        self.collectionView2.reorderingCadence = .fast //default value - .immediate
        
        loadImage()
    }
    
    
    private func loadImage() {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(atPath: CCUtility.getDirectoryPDFGenerator()!)
            for fileName in directoryContents {
                items1.append(fileName)
            }
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    //MARK: Private Methods
    
    /// This method moves a cell from source indexPath to destination indexPath within the same collection view. It works for only 1 item. If multiple items selected, no reordering happens.
    ///
    /// - Parameters:
    ///   - coordinator: coordinator obtained from performDropWith: UICollectionViewDropDelegate method
    ///   - destinationIndexPath: indexpath of the collection view where the user drops the element
    ///   - collectionView: collectionView in which reordering needs to be done.
    private func reorderItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView)
    {
        let items = coordinator.items
        if items.count == 1, let item = items.first, let sourceIndexPath = item.sourceIndexPath
        {
            var dIndexPath = destinationIndexPath
            if dIndexPath.row >= collectionView.numberOfItems(inSection: 0)
            {
                dIndexPath.row = collectionView.numberOfItems(inSection: 0) - 1
            }
            collectionView.performBatchUpdates({
                if collectionView === self.collectionView2
                {
                    self.items2.remove(at: sourceIndexPath.row)
                    self.items2.insert(item.dragItem.localObject as! String, at: dIndexPath.row)
                }
                else
                {
                    self.items1.remove(at: sourceIndexPath.row)
                    self.items1.insert(item.dragItem.localObject as! String, at: dIndexPath.row)
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
            for (index, item) in coordinator.items.enumerated()
            {
                let indexPath = IndexPath(row: destinationIndexPath.row + index, section: destinationIndexPath.section)
                if collectionView === self.collectionView2
                {
                    self.items2.insert(item.dragItem.localObject as! String, at: indexPath.row)
                }
                else
                {
                    self.items1.insert(item.dragItem.localObject as! String, at: indexPath.row)
                }
                indexPaths.append(indexPath)
            }
            collectionView.insertItems(at: indexPaths)
        })
    }
}

// MARK: - UICollectionViewDataSource Methods

@available(iOS 11, *)

extension DragDropViewController : UICollectionViewDataSource
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return collectionView == self.collectionView1 ? self.items1.count : self.items2.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        if collectionView == self.collectionView1
        {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell1", for: indexPath) as! ScanCell
            
            let fileNamePath = CCUtility.getDirectoryPDFGenerator() + "/" + self.items1[indexPath.row]
            let data = try? Data(contentsOf: fileNamePath.url)
            cell.customImageView?.image = UIImage(data: data!)
            cell.customLabel.text = self.items1[indexPath.row].capitalized
            return cell
        }
        else
        {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell2", for: indexPath) as! ScanCell
            
            let fileNamePath = CCUtility.getDirectoryPDFGenerator() + "/" + self.items2[indexPath.row]
            let data = try? Data(contentsOf: fileNamePath.url)
            cell.customImageView?.image = UIImage(data: data!)
            cell.customLabel.text = self.items2[indexPath.row].capitalized
            return cell
        }
    }
}

// MARK: - UICollectionViewDragDelegate Methods

@available(iOS 11, *)

extension DragDropViewController : UICollectionViewDragDelegate
{
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem]
    {
        let item = collectionView == collectionView1 ? self.items1[indexPath.row] : self.items2[indexPath.row]
        let itemProvider = NSItemProvider(object: item as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem]
    {
        let item = collectionView == collectionView1 ? self.items1[indexPath.row] : self.items2[indexPath.row]
        let itemProvider = NSItemProvider(object: item as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters?
    {
        if collectionView == collectionView1
        {
            let previewParameters = UIDragPreviewParameters()
            previewParameters.visiblePath = UIBezierPath(rect: CGRect(x: 25, y: 25, width: 120, height: 120))
            return previewParameters
        }
        return nil
    }
}

// MARK: - UICollectionViewDropDelegate Methods

@available(iOS 11, *)

extension DragDropViewController : UICollectionViewDropDelegate
{
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool
    {
        return session.canLoadObjects(ofClass: NSString.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal
    {
        if collectionView === self.collectionView1
        {
            if collectionView.hasActiveDrag
            {
                return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            }
            else
            {
                return UICollectionViewDropProposal(operation: .forbidden)
            }
        }
        else
        {
            if collectionView.hasActiveDrag
            {
                return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            }
            else
            {
                return UICollectionViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator)
    {
        let destinationIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath
        {
            destinationIndexPath = indexPath
        }
        else
        {
            // Get last index path of table view.
            let section = collectionView.numberOfSections - 1
            let row = collectionView.numberOfItems(inSection: section)
            destinationIndexPath = IndexPath(row: row, section: section)
        }
        
        switch coordinator.proposal.operation
        {
        case .move:
            self.reorderItems(coordinator: coordinator, destinationIndexPath:destinationIndexPath, collectionView: collectionView)
            break
            
        case .copy:
            self.copyItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
            
        default:
            return
        }
    }
}

