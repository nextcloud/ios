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
//    @State private var emojiText: String = "😀"
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Input field with emoji
                HStack(spacing: 12) {
                    EmojiField(text: $model.emojiText)

                    TextField("What is your status?", text: $model.statusText)
                        .focused($isTextFieldFocused)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(height: 20)

                // Presets list
                VStack(spacing: 18) {
                    ForEach(model.statusPresets) { preset in
                        StatusPresetRow(model: $model, preset: preset)
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
                        Picker("Clear after", selection: $model.clearAfter) {
                            ForEach(NCStatusMessageModel.ClearAfter.allCases) { option in
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
                        model.clearStatus()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
//                    .foregroundStyle(.blue)

                    Spacer()

                    Button(action: {}) {
                        Text("Set message")
                            .fontWeight(.semibold)
//                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)

                    }
                    .buttonStyle(.borderedProminent)
//                    .tint(Color(.systemGray3))
//                    .foregroundStyle(Color(.systemBackground))
//                    .clipShape(Capsule())
//                    .frame(width: 220)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isTextFieldFocused = false
        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//        .background(Color(.systemBackground))
        .navigationTitle(NSLocalizedString("_select_status_message_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatusPresetRow: View {
    @Binding var model: NCStatusMessageModel
    let preset: NCStatusMessageModel.StatusPreset

    var body: some View {
        Button(action: {
            model.chooseStatusPreset(preset: preset)
        }) {
            HStack(spacing: 16) {
                Text(preset.emoji)
                    .font(.title2)
                    .frame(width: 32)
                Text(preset.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("—")
                    .foregroundStyle(.secondary)
                Text(preset.clearAfter.rawValue)
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
