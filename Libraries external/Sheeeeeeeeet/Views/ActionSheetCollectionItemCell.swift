import Foundation

open class ActionSheetCollectionItemCell: ActionSheetItemCell {
    
    
    // MARK: - Properties
    
    static var itemCellIdentifier: String { return "Cell" }
    
    static var nib: UINib = UINib(nibName: "ActionSheetCollectionItemCell", bundle: Bundle.init(for: ActionSheetCollectionItemCell.self))
    
    
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
