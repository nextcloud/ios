//
//  UIDeviceOrientation+Utils.swift
//  WeScan
//
//  Created by Boris Emorine on 2/13/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation
import AVFoundation

extension AVCaptureVideoOrientation {
    
    /// Maps UIDeviceOrientation to AVCaptureVideoOrientation
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait:
            self.init(rawValue: AVCaptureVideoOrientation.portrait.rawValue)
        case .portraitUpsideDown:
            self.init(rawValue: AVCaptureVideoOrientation.portraitUpsideDown.rawValue)
        case .landscapeLeft:
            self.init(rawValue: AVCaptureVideoOrientation.landscapeLeft.rawValue)
        case .landscapeRight:
            self.init(rawValue: AVCaptureVideoOrientation.landscapeRight.rawValue)
        case .faceUp:
            self.init(rawValue: AVCaptureVideoOrientation.portrait.rawValue)
        case .faceDown:
            self.init(rawValue: AVCaptureVideoOrientation.portraitUpsideDown.rawValue)
        default:
            self.init(rawValue: AVCaptureVideoOrientation.portrait.rawValue)
        }
    }
    
}
