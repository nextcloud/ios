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

public class EditCoreContext {

    var ecc : OpaquePointer;

    init(interactive : Bool, nRenderingThreads : Int32) {
         ecc = IM_EditCoreContext_alloc(interactive, nRenderingThreads)
    }
    
    deinit {
         IM_EditCoreContext_release(ecc)
    }


    func add_font(fontFile : String) {
      	 IM_EditCoreContext_add_font(ecc, UnsafePointer(fontFile))
    }

    func set_EditCoreUIControl(uiControl : EditCoreUIControl) {
        IM_EditCoreContext_set_EditCoreUIControl(ecc, uiControl.get_C_uiControl())
    }

    func load_from_bundle_directory(bundleDirectory : String) -> IMError {
    	 let c_err = IM_EditCoreContext_load_from_bundle_directory(ecc, UnsafePointer(bundleDirectory))!
        return IMError(ptr: c_err)
    }

    // enum IM_IMMLoadingState IM_EditCoreContext_get_imm_loading_state(struct IM_EditCoreContext*);

    func ready_to_initialize_openGL() -> Bool {
    	 return IM_EditCoreContext_ready_to_initialize_openGL(ecc)
    }

    func get_EditCore() -> EditCore {
        let c_editcore = IM_EditCoreContext_get_EditCore(ecc)!
        return EditCore(ptr: c_editcore)
    }

    func load_auxiliary_files() -> IMError {
    	 let c_err = IM_EditCoreContext_load_auxiliary_files(ecc)!
        return IMError(ptr: c_err)
    }

    func init_OpenGL_resources() -> IMError {
    	 let c_err = IM_EditCoreContext_init_OpenGL_resources(ecc)!
        return IMError(ptr: c_err)
    }

    func set_OpenGL_viewport(viewport_width : Int32, viewport_height : Int32, density_dpi : Float) {
    	 IM_EditCoreContext_set_OpenGL_viewport(ecc, viewport_width, viewport_height, density_dpi)
    }

    func set_displayTransform_tmp() {
        IM_EditCoreContext_set_displayTransform(ecc, IM_ImageFitMode_GeometricMean, false);
    }

    func free_OpenGL_resources() {
    	 IM_EditCoreContext_free_OpenGL_resources(ecc)
    }

// Manually render the scene before drawing. Only needed when there are no rendering threads.
//void render();

//void wait_until_rendering_is_finished();

    func draw_to_OpenGL() {
        IM_EditCoreContext_draw_to_OpenGL(ecc);
    }
}
