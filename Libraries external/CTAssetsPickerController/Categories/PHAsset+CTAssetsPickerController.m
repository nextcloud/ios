/*
 
 MIT License (MIT)
 
 Copyright (c) 2015 Clement CN Tsang
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 */

#import "PHAsset+CTAssetsPickerController.h"
#import "UIImage+CTAssetsPickerController.h"



@implementation PHAsset (CTAssetsPickerController)

- (BOOL)ctassetsPickerIsPhoto
{
    return (self.mediaType == PHAssetMediaTypeImage);
}

- (BOOL)ctassetsPickerIsVideo
{
    return (self.mediaType == PHAssetMediaTypeVideo);
}

- (BOOL)ctassetsPickerIsHighFrameRateVideo
{
    return (self.mediaType == PHAssetMediaTypeVideo && (self.mediaSubtypes & PHAssetMediaSubtypeVideoHighFrameRate));
}

- (BOOL)ctassetsPickerIsTimelapseVideo
{
    return (self.mediaType == PHAssetMediaTypeVideo && (self.mediaSubtypes & PHAssetMediaSubtypeVideoTimelapse));    
}

- (UIImage *)badgeImage
{
    NSString *imageName;
    
    if (self.ctassetsPickerIsHighFrameRateVideo)
        imageName = @"BadgeSlomoSmall";
    
    else if (self.ctassetsPickerIsTimelapseVideo)
        imageName = @"BadgeTimelapseSmall";
    
    else if (self.ctassetsPickerIsVideo)
        imageName = @"BadgeVideoSmall";
    
    if (imageName)
        return [[UIImage ctassetsPickerImageNamed:imageName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    else
        return nil;
}

- (NSString *)ctassetsPickerAccessibilityLabel
{
    return nil;
}


@end
