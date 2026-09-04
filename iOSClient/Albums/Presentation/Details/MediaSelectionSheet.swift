import SwiftUI

/// A reusable SwiftUI sheet that presents the NCMedia selection UI
/// and returns the selected file identifiers.
struct MediaSelectionSheet: View {
    // MARK: - Callbacks
    let onCancel: () -> Void
    let onDone: (_ selectedFiles: [String]) -> Void

    // MARK: - State
    @State private var isLoaded: Bool = false
    @State private var selectedFiles: [String] = []

    var body: some View {
        NavigationView {
            NCMediaHost(
                storyboardName: "NCMedia",
                sceneIdentifier: "NCMedia.storyboard",
                isSelectionContext: true,
                onLoaded: {
                    // Ensure media is fully initialized (metadata ready)
                    isLoaded = true
                },
                onSelectionChange: { files in
                    selectedFiles = files
                }
            )
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
                        onDone(selectedFiles)
                    }
                    .foregroundColor(Color(NCBrandColor.shared.customer))
                    .disabled(!isLoaded)
                    .opacity(isLoaded ? 1.0 : 0.5)
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
