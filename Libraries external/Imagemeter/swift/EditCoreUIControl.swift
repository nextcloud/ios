/*
 * ImageMeter confidential
 *
 * Copyright (C) 2018-2019 by Dirk Farin, Kronenstr. 49b, 70174 Stuttgart, Germany
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


public class EditCoreUIControl {
    
    var uiControl : OpaquePointer;
    var mCallbacks : IM_EditCoreUIControl_Callbacks;
    
    init(callbacks : IM_EditCoreUIControl_Callbacks) {
        mCallbacks = callbacks
        uiControl = IM_EditCoreUIControl_alloc(&mCallbacks) // UnsafeMutablePointer<IM_EditCoreUIControl_Callbacks>(&callbacks))
    }
    
    deinit {
        IM_EditCoreUIControl_release(uiControl)
    }
    
    func get_C_uiControl() -> OpaquePointer {
        return uiControl
    }
}
