
import UIKit

@IBDesignable
class NCViewerImageNibLoadingView: UIView {

    @IBOutlet weak var view: UIView!

    public override init(frame: CGRect) {
        super.init(frame: frame)
        view = NCViewerImageNibLoading.nibSetup(self)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        view = NCViewerImageNibLoading.nibSetup(self)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.view.backgroundColor = .clear
    }
}

private class NCViewerImageNibLoading: NSObject {
    class func loadViewFromNib(_ obj: UIView) -> UIView {
        let bundle = Bundle(for: type(of: obj))
        let nib = UINib(nibName: String(describing: type(of: obj)), bundle: bundle)
        let nibView = (nib.instantiate(withOwner: obj, options: nil).first as? UIView)!
        return nibView
    }

    class func nibSetup(_ obj: UIView) -> UIView {
        obj.backgroundColor = .clear
        let view: UIView = NCViewerImageNibLoading.loadViewFromNib(obj)
        view.frame = obj.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.translatesAutoresizingMaskIntoConstraints = true
        obj.addSubview(view)
        return view
    }
}
