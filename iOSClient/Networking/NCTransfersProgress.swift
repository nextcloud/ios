//
//  NCff.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

public class NCTransferProgress: NSObject {
    static let shared = NCTransferProgress()

    public class Transfer {
        var ocIdTransfer: String
        var session: String
        var progressNumber: NSNumber
        var totalBytes: Int64
        var totalBytesExpected: Int64

        init(ocIdTransfer: String, session: String, progressNumber: NSNumber, totalBytes: Int64, totalBytesExpected: Int64) {
            self.ocIdTransfer = ocIdTransfer
            self.session = session
            self.progressNumber = progressNumber
            self.totalBytes = totalBytes
            self.totalBytesExpected = totalBytesExpected
        }
    }
    private var transfers = ThreadSafeArray<Transfer>()

    func append(_ transfer: Transfer) {
        transfers.append(transfer)
    }

    func remove(ocIdTransfer: String) {
        transfers.remove(where: { $0.ocIdTransfer == ocIdTransfer })
    }

    func removeAll() {
        transfers.removeAll()
    }

    func get(ocIdTransfer: String) -> Transfer? {
        return transfers.filter({ $0.ocIdTransfer == ocIdTransfer}).first
    }

    func get(ocIdTransfer: String, session: String) -> Transfer {
        if let transfer = transfers.filter({ $0.ocIdTransfer == ocIdTransfer}).first {
            return transfer
        }
        return Transfer(ocIdTransfer: ocIdTransfer, session: session, progressNumber: 0, totalBytes: 0, totalBytesExpected: 0)
    }
}
