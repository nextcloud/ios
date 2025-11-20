// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

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
                HStack(spacing: 12) {
                    EmojiField(text: $model.emojiText)

                    TextField("What is your status?", text: $model.statusText)
                        .focused($isTextFieldFocused)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(height: 20)

                VStack(spacing: 18) {
                    ForEach(model.statusPresets) { preset in
                        StatusPresetRow(model: $model, preset: preset)
                    }
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Clear status after")
                        .font(.headline)
                    Picker("Clear after", selection: $model.clearAfter) {
                        ForEach(NCStatusMessageModel.ClearAfter.allCases) { option in
                            Text(NSLocalizedString(option.rawValue, comment: "")).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Bottom actions
                HStack(spacing: 80) {
                    Button("Clear") {
                        model.clearStatus()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
//                    .foregroundStyle(.blue)

                    Button("Set message") {
                        // Set message action
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
//                    .tint(Color(.systemGray3))
//                    .foregroundStyle(Color(.systemBackground))
//                    .clipShape(Capsule())
//                    .frame(width: 220)
                }
//                .frame(minWidth: 0, maxWidth: .infinity)
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
        .onAppear {
            model.getPredefinedStatusTexts(account: account)
        }
    }
}

private struct StatusPresetRow: View {
    @Binding var model: NCStatusMessageModel
    let preset: NKUserStatus

    var body: some View {
        let cleatAtText = model.getPredefinedClearStatusText(clearAt: preset.clearAt, clearAtTime: preset.clearAtTime, clearAtType: preset.clearAtType)

        Button(action: {
            model.chooseStatusPreset(preset: preset, clearAtText: cleatAtText)
        }) {
            HStack(spacing: 16) {
                Text(preset.icon ?? "")
                    .font(.title3)
                    .frame(width: 32)
                Text(preset.message ?? "")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("—")
                    .foregroundStyle(.secondary)
                Text(cleatAtText)
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
