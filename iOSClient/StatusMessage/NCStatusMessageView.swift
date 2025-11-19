// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

struct Status: Identifiable, Equatable {
    let id = UUID()
    let emoji: String
    let title: String
    let detail: String
}

struct NCStatusMessageView: View {
    let account: String

    // MARK: - State
    @State private var model = NCStatusMessageModel()
//    @State private var statusText: String = ""
//    @State private var selectedStatus: Status?
    @State private var clearAfter: ClearAfter = .dontClear
//    @State private var emojiText: String = "😀"

    enum ClearAfter: String, CaseIterable, Identifiable {
        case dontClear = "Don't clear"
        case thirtyMinutes = "In 30 minutes"
        case oneHour = "In 1 hour"
        case today = "Today"
        case thisWeek = "This week"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Input field with emoji
            HStack(alignment: .top, spacing: 12) {
                EmojiField(text: $model.emojiText)
                    .frame(width: 40, height: 40, alignment: .center)
                    .background(Color.clear)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.secondary.opacity(0.6), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground).opacity(0.2))
                        )

                    TextField("What is your status?", text: $model.statusText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
//                .frame(minHeight: 72)
            }

            // Presets list
            VStack(spacing: 18) {
                ForEach(model.statusPresets) { preset in
                    StatusRow(preset: preset) {
                        model.selectedStatus = preset
                        model.emojiText = preset.emoji
                        model.statusText = preset.title
                        // Update clearAfter suggestion if present
                        switch preset.title {
                        case "In a meeting": clearAfter = .oneHour
                        case "Commuting": clearAfter = .thirtyMinutes
                        case "Working remotely": clearAfter = .today
                        case "Out sick": clearAfter = .today
                        case "Vacationing": clearAfter = .dontClear
                        default: break
                        }
                    }
                }
            }
            .padding(.top, 8)

            // Clear after section
            VStack(alignment: .leading, spacing: 8) {
                Text("Clear status after")
                    .font(.headline)
                HStack(spacing: 12) {
                    Text("🌴")
                        .font(.title3)
                    Picker("Clear after", selection: $clearAfter) {
                        ForEach(ClearAfter.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Bottom actions
            HStack {
                Button("Clear") {
                    model.statusText = ""
                    model.selectedStatus = nil
                    clearAfter = .dontClear
                    model.emojiText = "😀"
                }
                .foregroundStyle(.blue)

                Spacer()

                Button(action: setMessage) {
                    Text("Set message")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(.systemGray3))
                .foregroundStyle(Color(.systemBackground))
                .clipShape(Capsule())
                .frame(width: 220)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground))
    }

    private func setMessage() {
        // Hook up to your model or networking here.
        // For now we just print to console.
        let preset = model.selectedStatus?.title ?? "Custom"
        print("Set status: \(model.emojiText) \(model.statusText.isEmpty ? preset : model.statusText) — clear: \(clearAfter.rawValue)")
    }
}

private struct StatusRow: View {
    let preset: Status
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(preset.emoji)
                    .font(.title2)
                    .frame(width: 32)
                Text(preset.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("—")
                    .foregroundStyle(.secondary)
                Text(preset.detail)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview() {
    NCStatusMessageView(account: "")
}
