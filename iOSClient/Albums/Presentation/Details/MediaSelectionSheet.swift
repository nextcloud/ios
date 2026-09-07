import SwiftUI

/// A reusable SwiftUI sheet that presents the NCMedia selection UI
/// and returns the selected file identifiers.
struct MediaSelectionSheet: View {
    // MARK: - Callbacks
    let onCancel: () -> Void
    let onDone: (_ selectedFiles: [String]) -> Void

    // MARK: - State
    @State private var mediaVC: NCMedia?

    var body: some View {
        NavigationView {
            NCMediaViewRepresentable(ncMedia: $mediaVC)
            .navigationTitle(NSLocalizedString("_albums_photo_selection_sheet_title_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("_albums_photo_selection_sheet_back_btn_", comment: "")) {
                        onCancel()
                    }
                    .foregroundColor(Color(NCBrandColor.shared.customer))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("_albums_photo_selection_sheet_done_btn_", comment: "")) {
                        onDone(mediaVC?.fileSelect ?? [])
                    }
                    .foregroundColor(Color(NCBrandColor.shared.customer))
                    .disabled(mediaVC == nil)
                    .opacity(mediaVC == nil ? 0.5 : 1.0)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    MediaSelectionSheet(
        onCancel: {},
        onDone: { _ in }
    )
}
#endif
