
import UIKit

class NCViewerImageView: NCViewerImageNibLoadingView {
    @IBOutlet weak var collectionView: UICollectionView!

    public var assets: [NCViewerImageAsset?]? {
        didSet {
            self.collectionView.reloadData()
        }
    }

    private var preselectedIndex: Int = -1

    override public func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        self.collectionView.register(UINib.init(nibName: String(describing: NCViewerImageCollectionViewCell.self), bundle: Bundle(for: type(of: self))), forCellWithReuseIdentifier: NCViewerImageCollectionViewCell.reusableIdentifier)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.collectionView.collectionViewLayout.invalidateLayout()
        if let indexPath = self.collectionView.indexPathsForVisibleItems.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
            }
        }
    }

    public func preselectItem(at index: Int) {
        self.preselectedIndex = index
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        if preselectedIndex != -1 {
            self.collectionView.scrollToItem(at: IndexPath(row: self.preselectedIndex, section: 0), at: .centeredHorizontally, animated: false)
            preselectedIndex = -1
        }
    }
}

extension NCViewerImageView: UICollectionViewDataSource {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets?.count ?? 0
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: NCViewerImageCollectionViewCell = (collectionView.dequeueReusableCell(withReuseIdentifier: NCViewerImageCollectionViewCell.reusableIdentifier, for: indexPath) as? NCViewerImageCollectionViewCell)!
        cell.withImageAsset(assets?[indexPath.row])
        cell.delegate = self
        return cell
    }
}

extension NCViewerImageView: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? NCViewerImageCollectionViewCell)?.cancelPendingDataTask()
    }

    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? NCViewerImageCollectionViewCell)?.withImageAsset(assets?[indexPath.row])
    }
}

extension NCViewerImageView: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: floor(collectionView.frame.size.width), height: floor(collectionView.frame.size.height))
    }
}

extension NCViewerImageView: NCViewerImageCollectionViewCellDelegate {
    func didStartZooming(_ cell: NCViewerImageCollectionViewCell) {

    }
}
