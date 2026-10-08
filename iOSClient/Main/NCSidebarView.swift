// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A leading overlay with glass buttons kept inside the panel.
@MainActor
struct NCSidebarView: View {
    let onClose: () -> Void
    let openSettings: () -> Void
    @State private var isVisible = false
    @State private var isClosing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            // Keep a strip of the underlying screen visible on compact displays.
            let width = max(0, min(320, geometry.size.width - 56))
            ZStack(alignment: .leading) {
                Color.black.opacity(isVisible ? 0.25 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { close(then: onClose) }
                    .accessibilityHidden(true)

                VStack {
                    sidebarHeader
                        .padding()
                    Spacer()
                }
                .frame(width: width)
                .frame(maxHeight: .infinity)
                .background {
                    sidebarBackground
                        .ignoresSafeArea(.container, edges: .vertical)
                }
                .offset(x: isVisible ? 0 : -width)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { close(then: onClose) }
            }
            .task {
                // Wait 50 ms so SwiftUI can render the panel in its initial offscreen position.
                // Starting the animation during insertion can skip that first frame and make
                // the sidebar appear immediately instead of sliding in. This delay only
                // applies to opening; closing already starts from a rendered position.
                if !reduceMotion {
                    do {
                        try await Task.sleep(for: .milliseconds(50))
                    } catch {
                        return
                    }
                }
                guard !isClosing, !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    isVisible = true
                }
            }
        }
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: Rectangle())
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }

    @ViewBuilder
    private var sidebarHeader: some View {
        if #available(iOS 26.0, *) {
            headerButtons.buttonStyle(.glass)
        } else {
            headerButtons.buttonStyle(.bordered)
        }
    }

    private var headerButtons: some View {
        HStack {
            Button {
                close(then: openSettings)
            } label: {
                Label("_settings_", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .frame(width: 32, height: 32)
            }
            .accessibilityIdentifier("sidebarSettings")

            Spacer()

            Button {
                close(then: onClose)
            } label: {
                Label("_close_", systemImage: "sidebar.left")
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .frame(width: 32, height: 32)
            }
        }
        .buttonBorderShape(.circle)
        .controlSize(.regular)
    }

    private func close(then action: @escaping () -> Void) {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2), completionCriteria: .removed) {
            isVisible = false
        } completion: {
            action()
        }
    }
}
