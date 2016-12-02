//
//  UIImage+Blurring.h
//  NYXImagesKit
//
//  Created by @Nyx0uf on 03/06/11.
//  Copyright 2012 Nyx0uf. All rights reserved.
//  www.cocoaintheshell.com
//


#import "NYXImagesHelper.h"


@interface UIImage (NYX_Blurring)

-(UIImage*)gaussianBlurWithBias:(NSInteger)bias;

@end
