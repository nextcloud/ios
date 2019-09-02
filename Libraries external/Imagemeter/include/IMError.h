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

#ifndef IMAGEMETER_IMERROR_H
#define IMAGEMETER_IMERROR_H

#ifdef __cplusplus
extern "C" {
#endif

struct IM_Error;

void IM_Error_release(struct IM_Error*);

#ifdef __cplusplus
}
#endif

#endif //IMAGEMETER_IMERROR_H
