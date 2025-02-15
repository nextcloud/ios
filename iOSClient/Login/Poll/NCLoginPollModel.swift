import Foundation

class NCLoginPollModel: ObservableObject {
    @Published var isLoading = false

    func openLoginInBrowser(loginFlowV2Login: String = "") {
        UIApplication.shared.open(URL(string: loginFlowV2Login)!)
    }
}
