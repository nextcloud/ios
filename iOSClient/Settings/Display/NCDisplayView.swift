//
//  NCDisplayView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 30/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct NCDisplayView: View {
    @ObservedObject var model: NCDisplayModel
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    NCDisplayView(model: NCDisplayModel(controller: nil))
}
