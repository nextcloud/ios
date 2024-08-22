//
//  NCFileNameView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import SwiftUI

struct NCFileNameView: View {
    @ObservedObject var model: NCFileNameModel

    var body: some View {
        Form {
            /// Specify Filename
            Section(header: Text(NSLocalizedString("_mode_filename_", comment: ""))) {
                ///
                Toggle(NSLocalizedString("_maintain_original_filename_", comment: ""), isOn: $model.maintainFilenameOriginal)
                    .font(.system(size: 16))
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.maintainFilenameOriginal, perform: { newValue in
                        model.toggleMaintainFilenameOriginal(newValue: newValue)
                        model.getFileName()
                    })
                /// Filename
                if !model.maintainFilenameOriginal {
                    Toggle(NSLocalizedString("_add_filenametype_", comment: ""), isOn: $model.addFileNameType)
                        .font(.system(size: 16))
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.addFileNameType, perform: { newValue in
                            model.toggleAddFilenameType(newValue: newValue)
                            model.getFileName()
                        })
                }
            }
            .transition(.slide)
            .animation(.easeInOut, value: model.maintainFilenameOriginal)

            /// Filename Preview
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
                        .onChange(of: model.changedName, perform: { _ in
                            model.submitChangedName()
                            model.getFileName()
                        })
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
