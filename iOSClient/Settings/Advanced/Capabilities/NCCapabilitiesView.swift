//
//  NCCapabilitiesView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/05/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
import NextcloudKit

struct NCCapabilitiesView: View {
    @ObservedObject var model: NCCapabilitiesModel

    var body: some View {
        VStack {
            List {
                Section {
                    ForEach(model.capabililies, id: \.id) { capability in
                        HStack {
                            CapabilityName(text: Binding.constant(capability.text), image: Image(uiImage: capability.image), resize: capability.resize)
                            CapabilityStatus(available: capability.available)
                        }
                    }
                }
                Section {
                    CapabilityName(text: $model.homeServer, image: Image(uiImage: NCUtility().loadImage(named: "house")), resize: false)
                }
            }
        }
        .navigationBarTitle(NSLocalizedString("_capabilities_", comment: ""))
        .frame(maxWidth: .infinity, alignment: .top)
        .defaultViewModifier(model)
    }

    struct CapabilityName: View {
        @Binding var text: String
        @State var image: Image
        @State var resize: Bool

        var body: some View {
            Label {
                Text(text)
                    .font(.system(size: 15))
            } icon: {
                if resize {
                    image
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 23.0, height: 23.0)
                        .foregroundColor(.primary)
                } else {
                    image
                        .renderingMode(.template)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct CapabilityStatus: View {
        @State var available: Bool

        var body: some View {
            if available {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "multiply.circle.fill")
                    .foregroundColor(Color(NCBrandColor.shared.textColor2))
            }
        }
    }
}

#Preview {
    return NCCapabilitiesView(model: NCCapabilitiesModel(controller: nil))
}
