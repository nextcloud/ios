import Go2WorkKit
import SwiftUI

struct NCLoginPoll: View {
    let loginFlowV2Login: String

    @ObservedObject var model: NCLoginPollModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text(NSLocalizedString("_poll_desc_", comment: ""))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
                .padding()

            HStack {
                Button(NSLocalizedString("_cancel_", comment: "")) {
                    dismiss()
                }
                .disabled(model.isLoading)
                .buttonStyle(.bordered)
                .tint(.white)

                Button(NSLocalizedString("_retry_", comment: "")) {
                    model.openLoginInBrowser(loginFlowV2Login: loginFlowV2Login)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color(NCBrandColor.shared.customer))
                .tint(.white)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NCBrandColor.shared.customer))
        .onAppear {
            if !isRunningForPreviews {
                model.openLoginInBrowser(loginFlowV2Login: loginFlowV2Login)
            }
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    NCLoginPoll(loginFlowV2Login: "", model: NCLoginPollModel())
}
