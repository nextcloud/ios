//
//  NoPhotosEmptyView.swift
//  Nextcloud
//
//  Created by Dhanesh on 29/07/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct NoPhotosEmptyView: View {
    
    let onAddPhotosIntent: () -> Void
    
    private let contentPadding: CGFloat = 32.0
    
    var body: some View {
        
        ScrollView(.vertical) {
            
            VStack {
                
                // Background image
                Image("EmptyAlbum")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Foreground content
                VStack(alignment: .leading, spacing: 16) {
                    
                    Text(NSLocalizedString("_albums_photos_empty_heading_", comment: ""))
                        .font(.system(size: 48, weight: .bold))
                    
                    Text(NSLocalizedString("_albums_photos_empty_subheading_", comment: ""))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Button(action: onAddPhotosIntent) {
                        Label(NSLocalizedString("_albums_photos_empty_add_photos_btn_", comment: ""), systemImage: "plus")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(NCBrandColor.shared.customer))
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, contentPadding)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, -40)
            }
        }
    }
}

//#if DEBUG
//#Preview {
//    NavigationView {
//        NoPhotosEmptyView(
//            onAddPhotosIntent: {}
//        )
//        .navigationTitle("Album")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}
//#endif
