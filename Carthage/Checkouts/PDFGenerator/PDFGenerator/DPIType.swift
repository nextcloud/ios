//
//  DPIType.swift
//  PDFGenerator
//
//  Created by Suguru Kishimoto on 2016/06/21.
//
//

import Foundation
import UIKit

public enum DPIType {
    fileprivate static let defaultDpi: CGFloat = 72.0
    case `default`
    case dpi_300
    case custom(CGFloat)
    
    public var value: CGFloat {
        switch self {
        case .default:
            return type(of: self).defaultDpi
        case .dpi_300:
            return 300.0
        case .custom(let value) where value > 1.0:
            return value
        default:
            return DPIType.default.value
        }
    }
    
    public var scaleFactor: CGFloat {
        return self.value / DPIType.default.value
    }
}
