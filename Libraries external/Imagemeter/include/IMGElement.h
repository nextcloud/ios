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

#ifndef IMAGEMETER_IMGELEMENT_H
#define IMAGEMETER_IMGELEMENT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>


struct IM_GElement;

void IM_GElement_release(struct IM_GElement*);

void IM_GElement_set_main_color_argb(struct IM_GElement*, uint32_t argb);

uint32_t IM_GElement_get_main_color_argb(struct IM_GElement*);

void IM_GElement_set_main_line_width(struct IM_GElement*, float width);

float IM_GElement_get_main_line_width(struct IM_GElement*);

void IM_GElement_set_main_line_width_magnification(struct IM_GElement*, float magnification);

float IM_GElement_get_main_line_width_magnification(struct IM_GElement*);

void IM_GElement_set_main_font_base_size(struct IM_GElement*, float fontSize);

float IM_GElement_get_main_font_base_size(struct IM_GElement*);

void IM_GElement_set_main_font_base_size_magnification(struct IM_GElement*, float magnification);

float IM_GElement_get_main_font_base_size_magnification(struct IM_GElement*);

  
struct IM_Label* IM_GElement_get_label(struct IM_GElement*, int id);
  
  
#ifdef __cplusplus
}
#endif

#endif //IMAGEMETER_IMGELEMENT_H
