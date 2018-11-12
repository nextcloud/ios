import Foundation

open class ActionSheetCollectionItemCell: ActionSheetItemCell {
    
    
    // MARK: - Properties
    
    static let itemCellIdentifier = ActionSheetCollectionItemCell.className
    
    static let nib = ActionSheetCollectionItemCell.defaultNib
    
    
    // MARK: - Outlets
    
    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            let flow = UICollectionViewFlowLayout()
            flow.scrollDirection = .horizontal
            collectionView.collectionViewLayout = flow
        }
    }
    
    
    // MARK: - Functions
    
    func setup(withNib nib: UINib, owner: UICollectionViewDataSource & UICollectionViewDelegate) {
        let id = ActionSheetCollectionItemCell.itemCellIdentifier
        collectionView.contentInset = .zero
        collectionView.register(nib, forCellWithReuseIdentifier: id)
        collectionView.dataSource = owner
        collectionView.delegate = owner
        collectionView.reloadData()
    }
}
