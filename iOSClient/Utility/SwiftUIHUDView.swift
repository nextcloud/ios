//
//  SwiftUIHUDView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct SwiftUIHUDView: View {
     var body: some View {
        Text("Saved image")
            .foregroundColor(.gray)
            .padding(.horizontal, 10)
            .padding(14)
            .background(
                Blur(style: .systemMaterial)
                    .clipShape(Capsule())
                    .shadow(color: Color(.black).opacity(0.22), radius: 12, x: 0, y: 5)
                )
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

    @ViewBuilder var body: some View {
        ZStack {
            NavigationView {
                Button("Save image") {
                    self.showHUD.toggle()
                }
                .navigationTitle("Content View")
            }
            SwiftUIHUDView()
                .offset(y: showHUD ? 0 : -100)
                .animation(.easeOut)
        }
    }
}

struct SwiftUIHUDView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
