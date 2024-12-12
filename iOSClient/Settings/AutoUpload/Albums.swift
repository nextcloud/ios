//
//  Albums.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 12.12.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Photos

class Albums: ObservableObject {
    @Published var smartAlbums: [PHAssetCollection] = []
}
