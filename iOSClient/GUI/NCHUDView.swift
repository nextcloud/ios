//
//  HUDView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/01/23.
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

struct NCHUDView: View {
    @Binding var showHUD: Bool
    @State var textLabel: String
    @State var image: String
    @State var color: UIColor

    var body: some View {
        Button(action: {
            withAnimation {
                self.showHUD = false
            }
        }) {
            Label(textLabel, systemImage: image)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(14)
                .background(
                    Blur(style: .regular, color: color)
                        .clipShape(Capsule())
                        .shadow(color: Color(.black).opacity(0.22), radius: 12, x: 0, y: 5)
                    )
        }.buttonStyle(PlainButtonStyle())
    }
}

struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style
    var color: UIColor

    func makeUIView(context: Context) -> UIVisualEffectView {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: style))
        effectView.backgroundColor = color
        return effectView
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct ContentView: View {
    @State private var showHUD = false
    @State var color: UIColor
    @Namespace var hudAnimation

    func dismissHUDAfterTime() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showHUD = false
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                NavigationView {
                    Button("Save image") {
                        self.showHUD.toggle()
                    }
                    .navigationTitle("Content View")
                }
                NCHUDView(showHUD: $showHUD, textLabel: NSLocalizedString("_wait_", comment: ""), image: "doc.badge.arrow.up", color: color)
                    .offset(y: showHUD ? (geo.size.height / 2) : -200)
                    .animation(.easeOut, value: showHUD)
            }
        }
    }
}
