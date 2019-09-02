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

#ifndef IMAGEMETER_IMLABEL_H
#define IMAGEMETER_IMLABEL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>


struct IM_Label;

  
void IM_Label_release(struct IM_Label*);

// returns 'true' when this is a value dimension value
bool IM_Label_set_value_from_string(struct IM_Label*, const char* value_string);

const char* IM_Label_get_value_as_string(const struct IM_Label*);

  
#ifdef __cplusplus
}
#endif

#endif //IMAGEMETER_IMLABEL_H
