//
//  Optional+Extensions.swift
//  Nextcloud
//
//  Created by Milen on 24.05.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation

extension Optional where Wrapped: Collection {
    var isEmptyOrNil: Bool {
        return self?.isEmpty ?? true
    }
}
