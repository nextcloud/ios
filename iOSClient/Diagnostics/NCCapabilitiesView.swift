//
//  NCCapabilitiesView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/05/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct NCCapabilitiesView: View {
    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    Capability(text: "File sharing", image: Image("share"))
                    CapabilityAvailable(available: true)
                }
                HStack {
                    Capability(text: "Externa site", image: Image(systemName: "network"))
                    CapabilityAvailable(available: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 10))
        }
    }
}

struct Capability: View {

    @State var text: String = ""
    @State var image: Image

    var body: some View {
        Label {
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color(UIColor.systemGray))
        } icon: {
            image
                .renderingMode(.template)
                .resizable()
                .frame(width: 25.0, height: 25.0)
                .foregroundColor(Color(UIColor.systemGray))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CapabilityAvailable: View {

    @State private var text: String

    init(available: Bool) {
        if available {
            _text = State(initialValue: "✓ " + NSLocalizedString("_available_", comment: ""))
        } else {
            _text = State(initialValue: NSLocalizedString("_not_available_", comment: ""))

        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .padding(EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12))
            .foregroundColor(.primary)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(UIColor.systemGray), lineWidth: 0.5)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct NCCapabilitiesView_Previews: PreviewProvider {
    static var previews: some View {
        NCCapabilitiesView()
    }
}
