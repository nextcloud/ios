//
//  NCCollectionViewCommon+EndToEndInitializeDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

extension NCCollectionViewCommon: NCEndToEndInitializeDelegate {
    func endToEndInitializeSuccess(metadata: tableMetadata?) {
        if let metadata {
            pushMetadata(metadata)
        }
    }
}
