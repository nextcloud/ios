// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCFileNameView: View {
    @ObservedObject var model: NCFileNameModel

    var body: some View {
        Form {
            // Specify Filename
            Section(header: Text(NSLocalizedString("_mode_filename_", comment: ""))) {
                Toggle(NSLocalizedString("_maintain_original_filename_", comment: ""), isOn: $model.maintainFilenameOriginal)
                    .font(.system(size: 16))
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.maintainFilenameOriginal) { _, newValue in
                        model.toggleMaintainFilenameOriginal(newValue: newValue)
                        model.getFileName()
                    }
                // Filename
                if !model.maintainFilenameOriginal {
                    Toggle(NSLocalizedString("_add_filenametype_", comment: ""), isOn: $model.addFileNameType)
                        .font(.system(size: 16))
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.addFileNameType) { _, newValue in
                            model.toggleAddFilenameType(newValue: newValue)
                            model.getFileName()
                        }
                }
            }
            .transition(.slide)
            .animation(.easeInOut, value: model.maintainFilenameOriginal)

            // Filename Preview
            fileNamePreview
                .animation(.easeInOut, value: model.addFileNameType)
        }
        .navigationBarTitle(NSLocalizedString("_mode_filename_", comment: ""))
        .defaultViewModifier(model)
        .padding(.top, 0)
        .transition(.slide)
    }

    @ViewBuilder
    var fileNamePreview: some View {
        if !model.maintainFilenameOriginal {
            Section(content: {
                HStack {
                    Text(NSLocalizedString("_filename_", comment: ""))
                        .font(.system(size: 17))
                        .fontWeight(.medium)
                    Spacer()
                    TextField(NSLocalizedString("_filename_header_", comment: ""), text: $model.changedName)
                        .onChange(of: model.changedName) {
                            model.submitChangedName()
                            model.getFileName()
                        }
                        .autocapitalization(.none)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(size: 16))
                Text("\(model.fileNamePreview)")
                    .font(.system(size: 16))
                    .foregroundColor(Color(UIColor.lightGray))
            }, header: {
                Text(NSLocalizedString("_filename_", comment: ""))
            }, footer: {
                Text(String(format: NSLocalizedString("_preview_filename_", comment: ""), "MM, MMM, DD, YY, YYYY, HH, hh, mm, ss, ampm"))
            })
        } else {
            Section(content: {
                Text("IMG_0001.JPG")
                    .foregroundColor(Color(UIColor.lightGray))
            }, header: {
                Text(NSLocalizedString("_filename_", comment: ""))
            }, footer: {
                Text(NSLocalizedString("_default_preview_filename_footer_", comment: ""))
            })
        }

    }
}

#Preview {
    NCFileNameView(model: NCFileNameModel(controller: nil))
}
