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

public class GText {
    
    var gtext : OpaquePointer;
    
    init (elem : GElement) {
        gtext = IM_GText_from_GElement(elem.getCPtr())
    }
    
    deinit {
        IM_GText_release(gtext)
    }

    func set_text(text : String) {
        IM_GText_set_text(gtext, UnsafePointer(text))
    }
}

