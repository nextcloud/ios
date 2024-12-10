
import Foundation
import NextcloudKit

/// A model that allows the user to configure the account
class NCTermOfServiceModel: ObservableObject, ViewOnAppearHandling {
    /// AppDelegate
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    /// Root View Controller
    var controller: NCMainTabBarController?

    /// Set true for dismiss the view
    @Published var dismissView = false
    /// DB
    let database = NCManageDatabase.shared

    /// Initialization code to set up the ViewModel with the active account
    init(controller: NCMainTabBarController?, tos: NKTermsOfService) {
        self.controller = controller
        onViewAppear()
    }

    deinit {

    }

    /// Triggered when the view appears.
    func onViewAppear() {

    }
}
