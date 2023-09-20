//
//  Binding+Extension.swift
//  Nextcloud
//
//  Created by Milen on 20.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

prefix func ! (value: Binding<Bool>) -> Binding<Bool> {
    Binding<Bool>(
        get: { !value.wrappedValue },
        set: { value.wrappedValue = !$0 }
    )
}
