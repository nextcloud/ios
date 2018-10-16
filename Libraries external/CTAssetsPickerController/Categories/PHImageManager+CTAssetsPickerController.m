//
//  PHImageManager+CTSupport.m
//  CTAssetsPickerDemo
//
//  Created by Korben Allen Rusek on 4/7/16.
//  Copyright © 2016 Clement T. All rights reserved.
//

#import "PHImageManager+CTAssetsPickerController.h"

@implementation PHImageManager (CTAssetsPickerController)

+ (BOOL)ctassetsPickerNeedsiPadSupportSize {
    return [(NSString*)[UIDevice currentDevice].model hasPrefix:@"iPad"] && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad == false;
}

+ (CGSize)ctassetsPickerSizeForSize:(CGSize)size withMinimumDimension:(CGFloat)dimension {
    if (size.width >= dimension && size.height >= dimension) return size;
    if (size.width <= 0 || size.height <= 0) return size;
    
    CGFloat width, height;
    if (size.width < size.height) {
        width = 500;
        height = size.height/size.width*width;
    } else {
        height = 500;
        width = size.width/size.height*height;
    }
    return CGSizeMake(width, height);
}

- (PHImageRequestID)ctassetsPickerRequestImageForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:( PHImageRequestOptions *)options resultHandler:(void (^)(UIImage * result, NSDictionary * info))resultHandler {
    CGSize size = targetSize;
    if ([[self class] ctassetsPickerNeedsiPadSupportSize]) {
        size = [[self class] ctassetsPickerSizeForSize:targetSize withMinimumDimension:500];
    }
    return [self requestImageForAsset:asset targetSize:size contentMode:contentMode options:options resultHandler:resultHandler];
}

@end
