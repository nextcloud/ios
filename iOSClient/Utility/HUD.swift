//
//  HUD.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct HUD: View {

    @Binding var showHUD: Bool
    @State var textLabel: String
    @State var image: String

    var body: some View {
        Button(action: {
            withAnimation {
                self.showHUD = false
            }
        }) {
            Label(textLabel, systemImage: image)
                .foregroundColor(.gray)
                .padding(.horizontal, 10)
                .padding(14)
                .background(
                    Blur(style: .systemMaterial)
                        .clipShape(Capsule())
                        .shadow(color: Color(.black).opacity(0.22), radius: 12, x: 0, y: 5)
                    )
        }.buttonStyle(PlainButtonStyle())
    }
}

struct Blur: UIViewRepresentable {

    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct ContentView: View {

    @State private var showHUD = false
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
                HUD(showHUD: $showHUD, textLabel: "xxx", image: "photo")
                    .offset(y: showHUD ? (geo.size.height / 2) : -200)
                    .animation(.easeOut)
            }
        }
    }
}

struct HUD_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
