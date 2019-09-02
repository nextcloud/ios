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

#ifndef IMAGEMETER_IMEDITCOREUICONTROL_H
#define IMAGEMETER_IMEDITCOREUICONTROL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

struct IM_EditCoreUIControl;
struct IM_GElement;
  

// You may set unused callback functions to NULL.
//
struct IM_EditCoreUIControl_Callbacks
{
  // iOS see: https://stackoverflow.com/questions/7747742/on-demand-opengl-es-rendering-using-glkit
  void (*needsRedraw)();

  void (*scheduleTouchTimerEvent)(double delay_secs);

  void (*addingGElementFinished)(bool success);


  void (*activateGElement)(const struct IM_GElement* element);

  void (*deactivateGElement)();

  void (*updateDeleteButtonState)();

  void (*updateUndoUIButtonStates)();



  // --- element value entry
  
  void (*editTextBox)(int elementID);


  // --- playing audio ---

  bool (*supportsAudioPlayback)();

  bool (*playAudio)(const char* filename);

  void (*stopAudio)(const char* filename);
};


void IM_EditCoreUIControl_Callbacks_clear(struct IM_EditCoreUIControl_Callbacks*);
  

struct IM_EditCoreUIControl* IM_EditCoreUIControl_alloc(const struct IM_EditCoreUIControl_Callbacks*);

void IM_EditCoreUIControl_release(struct IM_EditCoreUIControl*);

#ifdef __cplusplus
}
#endif

#endif //IMAGEMETER_IMEDITCORE_H
