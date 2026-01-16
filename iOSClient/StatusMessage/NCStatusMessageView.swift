// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

struct NCStatusMessageView: View {
    let account: String

    @State private var model = NCStatusMessageModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    EmojiField(text: $model.emojiText)

                    TextField("_status_message_placehorder_", text: $model.statusText)
                        .focused($isTextFieldFocused)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(height: 20)

                VStack(spacing: 18) {
                    ForEach(model.predefinedStatuses) { preset in
                        StatusPresetRow(model: $model, preset: preset)
                    }
                }
                .padding(.top, 8)

                HStack {
                    Text("_clear_status_message_after_")
                    Menu {
                        ForEach(NCStatusMessageModel.ClearAfter.allCases) { option in
                            Button {
                                model.clearAfterString = option.rawValue
                            } label: {
                                Text(NSLocalizedString(option.rawValue, comment: ""))
                            }
                        }
                    } label: {
                        Text(NSLocalizedString(model.clearAfterString, comment: ""))
                            .foregroundStyle(.blue)
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                    }
                    Spacer()
                }

                HStack {
                    Button("_clear_") {
                        model.clearStatus(account: account)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Spacer()

                    Button("_set_status_message_") {
                        model.submitStatus(account: account)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.emojiText.isEmpty && model.statusText.isEmpty)
                }
                .padding(8)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isTextFieldFocused = false
        }
        .navigationTitle(NSLocalizedString("_select_status_message_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.getStatus(account: account)
            model.getPredefinedStatusTexts(account: account)
        }
        .onDisappear {
            model.setAccountUserStatus(account: account)
        }
    }
}

private struct StatusPresetRow: View {
    @Binding var model: NCStatusMessageModel
    let preset: NKUserStatus

    var body: some View {
        let cleatAtText = model.getPredefinedClearStatusString(clearAt: preset.clearAt, clearAtTime: preset.clearAtTime, clearAtType: preset.clearAtType)

        Button(action: {
            model.chooseStatusPreset(preset: preset, clearAtText: cleatAtText)
        }) {
            HStack(spacing: 16) {
                Text(preset.icon ?? "")
                    .font(.title3)
                    .frame(width: 32)
                Text(preset.message ?? "")
                    .font(.headline)
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
