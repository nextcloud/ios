//
//  PHImageManager+CTSupport.h
//  CTAssetsPickerDemo
//
//  Created by Korben Allen Rusek on 4/7/16.
//  Copyright © 2016 Clement T. All rights reserved.
//

#import <Photos/Photos.h>

@interface PHImageManager (CTAssetsPickerController)

- (PHImageRequestID)ctassetsPickerRequestImageForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:( PHImageRequestOptions *)options resultHandler:(void (^)(UIImage * result, NSDictionary * info))resultHandler;

@end
