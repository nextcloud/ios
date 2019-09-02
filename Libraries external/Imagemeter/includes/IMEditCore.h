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

#ifndef IMAGEMETER_IMEDITCORE_H
#define IMAGEMETER_IMEDITCORE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>


struct IM_EditCore;

void IM_EditCore_release(struct IM_EditCore*);


void IM_EditCore_touchDown(struct IM_EditCore*, int id, int x,int y, double timestamp_secs);

void IM_EditCore_touchMove(struct IM_EditCore*, int id, int x,int y, double timestamp_secs);

void IM_EditCore_touchUp(struct IM_EditCore*, int id, int x,int y, double timestamp_secs);

void IM_EditCore_touchCancelled(struct IM_EditCore*, int id);


void IM_EditCore_start_interaction_addMeasure(struct IM_EditCore*, const char* preset);

void IM_EditCore_start_interaction_addAngle(struct IM_EditCore*);

void IM_EditCore_start_interaction_addText(struct IM_EditCore*);

void IM_EditCore_start_interaction_addFreehand(struct IM_EditCore*);

void IM_EditCore_end_current_interaction(struct IM_EditCore*);


void IM_EditCore_set_color_of_active_element(struct IM_EditCore*,uint32_t argb);

void IM_EditCore_set_color_of_future_created_elements(struct IM_EditCore*,uint32_t argb);

void IM_EditCore_delete_active_element(struct IM_EditCore*);

void IM_EditCore_undo(struct IM_EditCore*);

void IM_EditCore_redo(struct IM_EditCore*);

bool IM_EditCore_undo_available(struct IM_EditCore*);

bool IM_EditCore_redo_available(struct IM_EditCore*);


void IM_EditCore_audioCompleted(struct IM_EditCore*, const char* audioFile);

#ifdef __cplusplus
}
#endif

#endif //IMAGEMETER_IMEDITCORE_H
