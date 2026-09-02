import SwiftUI
import UIKit

struct NCBlurEffectsTestView: View {
    private struct BlurStyle: Identifiable {
        let name: String
        let style: UIBlurEffect.Style

        var id: String {
            name
        }
    }

    private let styles: [BlurStyle] = [
        BlurStyle(
            name: ".systemUltraThinMaterial",
            style: .systemUltraThinMaterial
        ),
        BlurStyle(
            name: ".systemThinMaterial",
            style: .systemThinMaterial
        ),
        BlurStyle(
            name: ".systemMaterial",
            style: .systemMaterial
        ),
        BlurStyle(
            name: ".systemThickMaterial",
            style: .systemThickMaterial
        ),
        BlurStyle(
            name: ".systemChromeMaterial",
            style: .systemChromeMaterial
        ),

        BlurStyle(
            name: ".systemUltraThinMaterialLight",
            style: .systemUltraThinMaterialLight
        ),
        BlurStyle(
            name: ".systemThinMaterialLight",
            style: .systemThinMaterialLight
        ),
        BlurStyle(
            name: ".systemMaterialLight",
            style: .systemMaterialLight
        ),
        BlurStyle(
            name: ".systemThickMaterialLight",
            style: .systemThickMaterialLight
        ),
        BlurStyle(
            name: ".systemChromeMaterialLight",
            style: .systemChromeMaterialLight
        ),

        BlurStyle(
            name: ".systemUltraThinMaterialDark",
            style: .systemUltraThinMaterialDark
        ),
        BlurStyle(
            name: ".systemThinMaterialDark",
            style: .systemThinMaterialDark
        ),
        BlurStyle(
            name: ".systemMaterialDark",
            style: .systemMaterialDark
        ),
        BlurStyle(
            name: ".systemThickMaterialDark",
            style: .systemThickMaterialDark
        ),
        BlurStyle(
            name: ".systemChromeMaterialDark",
            style: .systemChromeMaterialDark
        )
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(styles) { item in
                    ZStack {
                        testBackground

                        NCBlurEffectView(style: item.style)

                        VStack(spacing: 2) {
                            Text("26-07-09 15-08-43 3.jpg")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Text(item.name)
                                .font(.caption2)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                    }
                    .frame(height: 52)
                    .clipShape(Capsule())
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var testBackground: some View {
        HStack(spacing: 0) {
            Color.white
            Color.blue
            Color.orange
            Color.black
        }
        .overlay {
            Image(systemName: "photo.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private struct NCBlurEffectView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(
            effect: UIBlurEffect(style: style)
        )
    }

    func updateUIView(
        _ uiView: UIVisualEffectView,
        context: Context
    ) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

#Preview {
    NCBlurEffectsTestView()
}
