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

public class EditCore {
    
    var editcore : OpaquePointer;
    
    init (ptr : OpaquePointer) {
        editcore = ptr
    }

    deinit {
        IM_EditCore_release(editcore)
    }
    

    func touchDown(id : Int32, x : Int32, y : Int32, timestamp_secs : Double) {
        IM_EditCore_touchDown(editcore, id, x,y, timestamp_secs)
    }
    
    func touchMove(id : Int32, x : Int32, y : Int32, timestamp_secs : Double) {
        IM_EditCore_touchMove(editcore, id, x,y, timestamp_secs)
    }
    
    func touchUp(id : Int32, x : Int32, y : Int32, timestamp_secs : Double) {
        IM_EditCore_touchUp(editcore, id, x,y, timestamp_secs)
    }
    
    func touchCancelled(id : Int32) {
        IM_EditCore_touchCancelled(editcore, id)
    }

    func start_interaction_addMeasure() {
        IM_EditCore_start_interaction_addMeasure(editcore, "")
    }

    // TODO: not fully working yet, because we need timer callbacks because of the double-click interactions
    func start_interaction_addAngle() {
        IM_EditCore_start_interaction_addAngle(editcore)
    }

    func start_interaction_addText() {
        IM_EditCore_start_interaction_addText(editcore)
    }

    func start_interaction_addFreehand() {
        IM_EditCore_start_interaction_addFreehand(editcore)
    }

    func end_current_interaction() {
        IM_EditCore_end_current_interaction(editcore)
    }
    
    func set_color_of_active_element(argb : UInt32) {
        IM_EditCore_set_color_of_active_element(editcore,argb)
    }

    func set_color_of_future_created_elements(argb : UInt32) {
        IM_EditCore_set_color_of_future_created_elements(editcore, argb)
    }

    func delete_active_element() {
        IM_EditCore_delete_active_element(editcore)
    }
    
    func undo() {
        IM_EditCore_undo(editcore)
    }
    
    func redo() {
        IM_EditCore_redo(editcore)
    }
    
    func undo_available() -> Bool {
        return IM_EditCore_undo_available(editcore)
    }
    
    func redo_available() -> Bool {
        return IM_EditCore_redo_available(editcore)
    }
    
    func audio_completed(audioFile : String) {
        IM_EditCore_audioCompleted(editcore, UnsafePointer(audioFile))
    }
}

