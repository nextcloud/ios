//
//  DataProtectionHostingController.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 26.11.2024.
//  Copyright © 2024 STRATO GmbH
//

import Foundation
import SwiftUI

class DataProtectionHostingController: UIHostingController<DataProtectionAgreementScreen> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
