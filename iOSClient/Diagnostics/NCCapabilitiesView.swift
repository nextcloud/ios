//
//  NCCapabilitiesView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/05/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

@objc class NCHostingCapabilitiesView: NSObject {

    @objc func makeShipDetailsUI() -> UIViewController {

        let capabilitiesStatus = NCCapabilitiesStatus()
        let view = NCCapabilitiesView(capabilitiesStatus: capabilitiesStatus)
        let vc = UIHostingController(rootView: view)
        vc.title = NSLocalizedString("_capabilities_", comment: "")
        return vc
    }
}

class NCCapabilitiesStatus: ObservableObject {

    struct Capability: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let image: UIImage
        let available: Bool
    }

    @Published var capabililies: [Capability] = []

    init(preview: Bool = false) {
        // if preview {
            capabililies = [Capability(text: "File sharing", image: UIImage(named: "share")!, available: true),
                            Capability(text: "Externa site", image: UIImage(systemName: "network")!, available: false)
            ]
        // }
    }
}

struct NCCapabilitiesView: View {

    @ObservedObject var capabilitiesStatus: NCCapabilitiesStatus

    init(capabilitiesStatus: NCCapabilitiesStatus) {
        self.capabilitiesStatus = capabilitiesStatus
    }

    var body: some View {
        ScrollView {
            VStack {
                ForEach(capabilitiesStatus.capabililies, id: \.id) { capability in
                    HStack {
                        Capability(text: capability.text, image: Image(uiImage: capability.image))
                        CapabilityAvailable(available: capability.available)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            //.padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
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
            _text = State(initialValue: NSLocalizedString("_available_", comment: ""))
        } else {
            _text = State(initialValue: NSLocalizedString("_not_available_", comment: ""))

        }
    }

    var body: some View {
        Text(text)
            .frame(width: 100)
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
        NCCapabilitiesView(capabilitiesStatus: NCCapabilitiesStatus(preview: true))
    }
}
