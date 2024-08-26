//
//  NCTransfersProgress.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import NextcloudKit

public class NCTransferProgress: NSObject {
    static let shared = NCTransferProgress()

    public class Transfer {
        var ocId: String
        var ocIdTransfer: String
        var session: String
        var chunk: Int
        var e2eEncrypted: Bool
        var progressNumber: NSNumber
        var totalBytes: Int64
        var totalBytesExpected: Int64
        var countError: Int = 0

        init(ocId: String, ocIdTransfer: String, session: String, chunk: Int, e2eEncrypted: Bool, progressNumber: NSNumber, totalBytes: Int64, totalBytesExpected: Int64) {
            self.ocId = ocId
            self.ocIdTransfer = ocIdTransfer
            self.session = session
            self.chunk = chunk
            self.e2eEncrypted = e2eEncrypted
            self.progressNumber = progressNumber
            self.totalBytes = totalBytes
            self.totalBytesExpected = totalBytesExpected
        }
    }
    private var transfers = ThreadSafeArray<Transfer>()
    private var lastOcIdTransferInForeground: String = ""

    override private init() {}

    @discardableResult
    func append(_ transfer: Transfer) -> Transfer {
        remove(ocIdTransfer: transfer.ocIdTransfer)
        transfers.append(transfer)
        if transfer.chunk > 0 || transfer.e2eEncrypted {
            lastOcIdTransferInForeground = transfer.ocIdTransfer
        }
        return transfer
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

    func get(ocId: String, ocIdTransfer: String, session: String) -> Transfer {
        if let transfer = transfers.filter({ $0.ocIdTransfer == ocIdTransfer}).first {
            return transfer
        }
        return Transfer(ocId: ocId, ocIdTransfer: ocIdTransfer, session: session, chunk: 0, e2eEncrypted: false, progressNumber: 0, totalBytes: 0, totalBytesExpected: 0)
    }

    func getAll() -> ThreadSafeArray<Transfer> {
        return transfers
    }

    func getLastTransferProgressInForeground() -> Float? {
        if !lastOcIdTransferInForeground.isEmpty {
            let transfer = get(ocIdTransfer: lastOcIdTransferInForeground)
            return transfer?.progressNumber.floatValue
        }
        return nil
    }

    func haveUploadInForeground() -> Bool {
        var result: Bool = false
        transfers.forEach { transfer in
            if transfer.chunk > 0 || transfer.e2eEncrypted {
                result = true
            }
        }
        return result
    }

    func addCountError(ocIdTransfer: String) {
        if let transfer = transfers.filter({ $0.ocIdTransfer == ocIdTransfer}).first {
            transfer.countError += 1
        }
    }

    func clearCountError(ocIdTransfer: String) {
        if let transfer = transfers.filter({ $0.ocIdTransfer == ocIdTransfer}).first {
            transfer.countError = 0
        }
    }

    func clearAllCountError() {
        transfers.forEach { transfer in
            transfer.countError = 0
        }
    }
}
