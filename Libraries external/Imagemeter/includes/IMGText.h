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

#ifndef IMAGEMETER_IMGTEXT_H
#define IMAGEMETER_IMGTEXT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>


struct IM_GText;

bool IM_GElement_is_GText(struct IM_GElement*);

struct IM_GText* IM_GText_from_GElement(struct IM_GElement*);

void IM_GText_release(struct IM_GText*);

void IM_GText_set_text(struct IM_GText*, const char* text);

const char* IM_GText_get_text(const struct IM_GText*);

void IM_GText_set_text_color_argb(struct IM_GText*, uint32_t argb);

uint32_t IM_GText_get_text_color_argb(const struct IM_GText*);

void IM_GText_set_show_border(struct IM_GText*, bool enable);

bool IM_GText_get_show_border(const struct IM_GText*);

void IM_GText_set_show_arrows(struct IM_GText*, bool enable);

bool IM_GText_get_show_arrows(const struct IM_GText*);

void IM_GText_set_fill_background(struct IM_GText*, bool enable);

bool IM_GText_get_fill_background(const struct IM_GText*);


void IM_GText_add_arrow(struct IM_GText*);

bool IM_GText_delete_arrow(const struct IM_GText*);


void IM_GText_set_audio_recording(struct IM_GText*, const char* filename, int duration_msecs);

void IM_GText_delete_audio_recording(struct IM_GText*);

const char* IM_GText_get_audio_recording_filename(const struct IM_GText*);

int IM_GText_get_audio_recording_duration_msecs(const struct IM_GText*);
  
  
#ifdef __cplusplus
}
#endif

#endif //IMAGEMETER_IMGTEXT_H
