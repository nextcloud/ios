//
// (See usage below implementation)
//
// SwiftUI `CollectionView` type implemented with UIKit's UICollectionView under the hood.
// Requires `UIViewControllerRepresentable` over `UIViewRepresentable` as the type that allows
// for SwiftUI `View`s to be added as subviews of UIKit `UIView`s at all bridges this gap as
// the `UIHostingController`.
//
// Not battle-tested yet, but seems to be working well so far.
// Expect changes.

import SwiftUI
import UIKit

struct CollectionView
    <Collections, CellContent>
    : UIViewControllerRepresentable
    where
    Collections : RandomAccessCollection,
    Collections.Index == Int,
    Collections.Element : RandomAccessCollection,
    Collections.Element.Index == Int,
    Collections.Element.Element : Identifiable,
    CellContent : View
{

    typealias Row = Collections.Element
    typealias Data = Row.Element
    typealias ContentForData = (Data) -> CellContent
    typealias ScrollDirection = UICollectionView.ScrollDirection
    typealias SizeForData = (Data) -> CGSize
    typealias CustomSizeForData = (UICollectionView, UICollectionViewLayout, Data) -> CGSize
    typealias RawCustomize = (UICollectionView) -> Void

    enum ContentSize {

        case fixed(CGSize)
        case variable(SizeForData)
        case crossAxisFilled(mainAxisLength: CGFloat)
        case custom(CustomSizeForData)
    }

    struct ItemSpacing : Hashable {

        var mainAxisSpacing: CGFloat
        var crossAxisSpacing: CGFloat
    }

    fileprivate let collections: Collections
    fileprivate let contentForData: ContentForData
    fileprivate let scrollDirection: ScrollDirection
    fileprivate let contentSize: ContentSize
    fileprivate let itemSpacing: ItemSpacing
    fileprivate let rawCustomize: RawCustomize?

    init(
        collections: Collections,
        scrollDirection: ScrollDirection = .vertical,
        contentSize: ContentSize,
        itemSpacing: ItemSpacing = ItemSpacing(mainAxisSpacing: 0, crossAxisSpacing: 0),
        rawCustomize: RawCustomize? = nil,
        contentForData: @escaping ContentForData)
    {
        self.collections = collections
        self.scrollDirection = scrollDirection
        self.contentSize = contentSize
        self.itemSpacing = itemSpacing
        self.rawCustomize = rawCustomize
        self.contentForData = contentForData
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(view: self)
    }

    func makeUIViewController(context: Context) -> ViewController {
        let coordinator = context.coordinator
        let viewController = ViewController(coordinator: coordinator, scrollDirection: self.scrollDirection)
        coordinator.viewController = viewController
        self.rawCustomize?(viewController.collectionView)
        return viewController
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // TODO: Obviously we can be efficient about what needs to be updated here
        context.coordinator.view = self
//        uiViewController.layout.scrollDirection = self.scrollDirection
//        self.rawCustomize?(uiViewController.collectionView)
        uiViewController.collectionView.reloadData()
    }
}

extension CollectionView {

    /*
     Convenience init for a single-section CollectionView
     */
    init<Collection>(
        collection: Collection,
        scrollDirection: ScrollDirection = .vertical,
        contentSize: ContentSize,
        itemSpacing: ItemSpacing = ItemSpacing(mainAxisSpacing: 0, crossAxisSpacing: 0),
        rawCustomize: RawCustomize? = nil,
        contentForData: @escaping ContentForData) where Collections == [Collection]
    {
        self.init(
            collections: [collection],
            scrollDirection: scrollDirection,
            contentSize: contentSize,
            itemSpacing: itemSpacing,
            rawCustomize: rawCustomize,
            contentForData: contentForData)
    }
}

extension CollectionView {

    fileprivate static var cellReuseIdentifier: String {
        return "HostedCollectionViewCell"
    }
}

extension CollectionView {

    final class ViewController : UIViewController {

        fileprivate let layout: UICollectionViewFlowLayout
        fileprivate let collectionView: UICollectionView
        init(coordinator: Coordinator, scrollDirection: ScrollDirection) {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = scrollDirection
            self.layout = layout

            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
            collectionView.backgroundColor = nil
            collectionView.register(MediaCell.self, forCellWithReuseIdentifier: MediaCell.identifier)
            collectionView.dataSource = coordinator
            collectionView.delegate = coordinator
            self.collectionView = collectionView
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("In no way is this class related to an interface builder file.")
        }

        override func loadView() {
            self.view = self.collectionView
        }
    }
}

extension CollectionView {

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

        fileprivate var view: CollectionView
        fileprivate var viewController: ViewController?

        init(view: CollectionView) {
            self.view = view
        }

        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return self.view.collections.count
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return self.view.collections[section].count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as? MediaCell
//            let data = self.view.collections[indexPath.section][indexPath.item]
//            let content = self.view.contentForData(data)
//            cell?.provide(content)
            cell?.backgroundColor = UIColor(hue: CGFloat(drand48()), saturation: 1, brightness: 1, alpha: 1)

            return cell!
        }

//        func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
//            let cell = cell as? HostedCollectionViewCell
//            cell?.attach(to: self.viewController!)
//        }
//
//        func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
//            let cell = cell as? HostedCollectionViewCell
//            cell?.detach()
//        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            return .init(width: 200, height: 100)
        }

//        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
//            return self.view.itemSpacing.mainAxisSpacing
//        }
//
//        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
//            return self.view.itemSpacing.crossAxisSpacing
//        }
    }
}

private extension CollectionView {

    final class HostedCollectionViewCell : UICollectionViewCell {

        var viewController: UIHostingController<CellContent>?

        func provide(_ content: CellContent) {
            if let viewController = self.viewController {
                viewController.rootView = content
            } else {
                let hostingController = UIHostingController(rootView: content)
                hostingController.view.backgroundColor = nil
                self.viewController = hostingController
            }
        }

        func attach(to parentController: UIViewController) {
            let hostedController = self.viewController!
            let hostedView = hostedController.view!
            let contentView = self.contentView

            parentController.addChild(hostedController)

            hostedView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(hostedView)
            hostedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            hostedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
            hostedView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            hostedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true

            hostedController.didMove(toParent: parentController)
        }

        func detach() {
            let hostedController = self.viewController!
            guard hostedController.parent != nil else { return }
            let hostedView = hostedController.view!

            hostedController.willMove(toParent: nil)
            hostedView.removeFromSuperview()
            hostedController.removeFromParent()
        }
    }
}


// Usage:

struct MyCustomData : Identifiable {

    let id: String
}

struct MyCustomCell : View {

    let data: MyCustomData

    var body: some View {
        ZStack(alignment: .center) {
            Text(self.data.id)
                .font(.system(size: 24))
                .foregroundColor(.red)
                .fontWeight(.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue.cornerRadius(14))
    }
}

struct MyCustomView : View {

    @State var items = (0...30).map({ MyCustomData(id: "\($0)") })

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    CollectionView(
                        collection: self.items,
                        scrollDirection: .horizontal,
                        contentSize: .crossAxisFilled(mainAxisLength: 40),
                        itemSpacing: .init(mainAxisSpacing: 24, crossAxisSpacing: 0),
                        rawCustomize: { collectionView in
                            collectionView.showsHorizontalScrollIndicator = false
                        },
                        contentForData: MyCustomCell.init)
                        .frame(height: 60)
                }
            }
        }
    }
}

struct MyCustomView_Previews: PreviewProvider {

    static var previews: some View {
        MyCustomView()
    }
}
