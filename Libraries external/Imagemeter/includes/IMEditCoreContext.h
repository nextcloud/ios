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

#ifndef IMAGEMETER_IMEDITCORECONTEXT_H
#define IMAGEMETER_IMEDITCORECONTEXT_H

#include "IMError.h"
#include "IMEditCore.h"

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

struct IM_EditCoreContext;


// from Geometry.h
enum IM_ImageFitMode
{
  IM_ImageFitMode_Fit = 0,          // fit image into screen to be completely visible
  IM_ImageFitMode_Fill = 1,         // fill screen completely (extending beyond borders)
  IM_ImageFitMode_GeometricMean = 2 // compromise between Fit and Fill (neither too small, nor too big)
};


// If nRenderingThreads==0, rendering has to be carried out manually
struct IM_EditCoreContext* IM_EditCoreContext_alloc(bool interactive,
                                                    int nRenderingThreads);

void IM_EditCoreContext_release(struct IM_EditCoreContext*);

void IM_EditCoreContext_add_font(struct IM_EditCoreContext*, const char* fontFile);

//void add_font(const std::vector<uint8_t>& fontData);

void IM_EditCoreContext_set_EditCoreUIControl(struct IM_EditCoreContext*, struct IM_EditCoreUIControl*);

//struct IM_Result* load_from_bundle(const std::shared_ptr<DataBundleCPP>& bundle);

struct IM_Error* IM_EditCoreContext_load_from_bundle_directory(struct IM_EditCoreContext*,
                                                               const char* bundleDirectory);

//IMResult<void> load_from_imm_file(Path bundleDirectory,
//                                  const std::shared_ptr<IMMFile>& imm);


enum IM_IMMLoadingState
{
  IM_IMMLoadingState_NotLoaded = 0,
  IM_IMMLoadingState_LoadingError = 1,
  IM_IMMLoadingState_LoadedIncompletely = 2, // some GElements could not be loaded. Ok for read-only, but do not overwrite.
  IM_IMMLoadingState_Loaded = 3
};

enum IM_IMMLoadingState IM_EditCoreContext_get_imm_loading_state(struct IM_EditCoreContext*);

bool IM_EditCoreContext_ready_to_initialize_openGL(struct IM_EditCoreContext*);


// returns true if the IMM has changed
//bool prepare_imm_for_saving();

//IMResult<void> restore_imm_to_stored_state();

// result.throws<IMError_DataBundle_CannotWriteIMM>();
//IMResult<void> save_to_bundle_directory();

// TODO: set a state whether loading the IMM failed / failed a bit / succeeded



// --- access to objects managed by the context

//std::shared_ptr<IMMFile> get_IMM_file();

struct IM_EditCore* IM_EditCoreContext_get_EditCore(struct IM_EditCoreContext*);

//std::shared_ptr<GLBackgroundImage> get_BackgroundImage() { return mBkgImage; }

//std::shared_ptr<EditCoreGraphics_OpenGLES2> get_EditCoreGraphics()

//std::shared_ptr<DataBundleCPP> get_data_bundle() { return mDataBundle; }


// --- drawing

// These functions (except render()) have to be called on the OpenGL thread

struct IM_Error* IM_EditCoreContext_load_auxiliary_files(struct IM_EditCoreContext*);

struct IM_Error* IM_EditCoreContext_init_OpenGL_resources(struct IM_EditCoreContext*);

void IM_EditCoreContext_set_OpenGL_viewport(struct IM_EditCoreContext*,
                                            int viewport_width,
                                            int viewport_height,
                                            float density_dpi);

void IM_EditCoreContext_set_displayTransform(struct IM_EditCoreContext*,
                                             enum IM_ImageFitMode mode, bool flipV);

//void set_displayTransform(AffineTransform transform);

//bool is_display_transform_set() const { return mDisplayTransformSet; }

void IM_EditCoreContext_free_OpenGL_resources(struct IM_EditCoreContext*);

// Manually render the scene before drawing. Only needed when there are no rendering threads.
//void render();

//void wait_until_rendering_is_finished();

void IM_EditCoreContext_draw_to_OpenGL(struct IM_EditCoreContext*);


#ifdef __cplusplus
}
#endif


#endif //IMAGEMETER_IMEDITCORECONTEXT_H
