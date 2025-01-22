import UIKit
import RealmSwift
import NextcloudKit

class NCMainNavigationController: UINavigationController {
    private var timerProcess: Timer?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.timerProcess = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            var color = NCBrandColor.shared.iconImageColor
            if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status != %i", NCGlobal.shared.metadataStatusNormal)),
               results.count > 0 {
                color = .red
            }
            for viewController in self.viewControllers {
                if let rightBarButtonItems = viewController.navigationItem.rightBarButtonItems {
                    if let buttonTransfer = rightBarButtonItems.first(where: { $0.tag == 2 }) {
                        buttonTransfer.tintColor = color
                    }
                }
            }
        })
    }
}
