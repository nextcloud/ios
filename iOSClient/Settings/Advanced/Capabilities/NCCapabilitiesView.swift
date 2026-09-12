// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
        let size = 26.0

        var body: some View {
            Label {
                Text(text)
                    .cappedFont(.body, maxDynamicType: .accessibility2)
            } icon: {
                if resize {
                    image
                        .resizable()
                        .frame(width: size, height: size)
                        .foregroundColor(.primary)
                } else {
                    image
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.primary)
                        .frame(width: size, height: size)
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
                    .font(.icon())
                    .foregroundColor(.green)
            } else {
                Image(systemName: "multiply.circle.fill")
                    .font(.icon())
                    .foregroundColor(Color(NCBrandColor.shared.textColor2))
            }
        }
    }
}

#Preview {
    return NCCapabilitiesView(model: NCCapabilitiesModel(controller: nil))
}
