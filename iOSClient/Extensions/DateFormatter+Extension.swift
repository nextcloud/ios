//
//  DateFormatter+Extension.swift
//  Nextcloud
//
//  Created by Henrik Storch on 18.03.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Foundation

extension DateFormatter {
    static let shareExpDate: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.dateStyle = .medium
        return dateFormatter
    }()
}
