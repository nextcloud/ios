// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// OCS API response with meta information.
///
/// The custom decoding implementation removes the `ocs` object from the data structure for convenience.
/// Meta and actual information are accessible directly as properties.
///
struct OCSResponse<ResponseDataType: Decodable>: Decodable {
    ///
    /// The `ocs` object in the response.
    ///
    struct OCSObject: Decodable {
        let data: ResponseDataType
        let meta: Meta
    }

    ///
    /// The `meta` object in an `ocs` response object.
    ///
    struct Meta: Decodable {
        let statuscode: Int
        let message: String
        let status: String
    }

    ///
    /// About the response itself.
    ///
    let meta: Meta

    ///
    /// Actual response content.
    ///
    let data: ResponseDataType

    enum CodingKeys: CodingKey {
        case data
        case meta
        case ocs
    }

    init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<OCSResponse<ResponseDataType>.CodingKeys> = try decoder.container(keyedBy: OCSResponse<ResponseDataType>.CodingKeys.self)
        let ocs = try container.decode(OCSObject.self, forKey: OCSResponse<ResponseDataType>.CodingKeys.ocs)
        self.meta = ocs.meta
        self.data = ocs.data
    }
}
