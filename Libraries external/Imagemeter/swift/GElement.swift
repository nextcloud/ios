/*
 * ImageMeter confidential
 *
 * Copyright (C) 2019 by Dirk Farin, Kronenstr. 49b, 70174 Stuttgart, Germany
 * All Rights Reserved.
 *
 * NOTICE:  All information contained herein is, and remains the property
 * of Dirk Farin.  The intellectual and technical concepts contained
 * herein are proprietary to Dirk Farin and are protected by trade secret
 * and copyright law.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from Dirk Farin.
 */

import Foundation

public class GElement {
    
    var gelement : OpaquePointer;
    
    init (ptr : OpaquePointer) {
        gelement = ptr
    }
    
    deinit {
        IM_GElement_release(gelement)
    }
   
    func set_main_line_width_magnification(magnification : Float) {
        IM_GElement_set_main_line_width_magnification(gelement, magnification)
    }
    
    func is_GText() -> Bool {
        return IM_GElement_is_GText(gelement)
    }
    
    func getCPtr() -> OpaquePointer {
        return gelement
    }
}

