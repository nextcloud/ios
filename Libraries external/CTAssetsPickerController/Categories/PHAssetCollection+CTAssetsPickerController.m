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

#import "PHAssetCollection+CTAssetsPickerController.h"
#import "UIImage+CTAssetsPickerController.h"



@implementation PHAssetCollection (CTAssetsPickerController)

+ (PHAssetCollectionType)ctassetPickerAssetCollectionTypeOfSubtype:(PHAssetCollectionSubtype)subtype
{
    return (subtype >= PHAssetCollectionSubtypeSmartAlbumGeneric) ? PHAssetCollectionTypeSmartAlbum : PHAssetCollectionTypeAlbum;
}

- (NSUInteger)ctassetPikcerCountOfAssetsFetchedWithOptions:(PHFetchOptions *)fetchOptions
{
    PHFetchResult *result = [PHAsset fetchAssetsInAssetCollection:self options:fetchOptions];
    return result.count;
}

- (UIImage *)badgeImage
{
    NSString *imageName;
    
    switch (self.assetCollectionSubtype)
    {
        case PHAssetCollectionSubtypeSmartAlbumUserLibrary:
            imageName = @"BadgeAllPhotos";
            break;
            
        case PHAssetCollectionSubtypeSmartAlbumPanoramas:
            imageName = @"BadgePanorama";
            break;
            
        case PHAssetCollectionSubtypeSmartAlbumVideos:
            imageName = @"BadgeVideo";
            break;
            
        case PHAssetCollectionSubtypeSmartAlbumFavorites:
            imageName = @"BadgeFavorites";
            break;
            
        case PHAssetCollectionSubtypeSmartAlbumTimelapses:
            imageName = @"BadgeTimelapse";
            break;
            
        case PHAssetCollectionSubtypeSmartAlbumRecentlyAdded:
            imageName = @"BadgeLastImport";
            break;
            
        case PHAssetCollectionSubtypeSmartAlbumBursts:
            imageName = @"BadgeBurst";
            break;
            
        case PHAssetCollectionSubtypeSmartAlbumSlomoVideos:
            imageName = @"BadgeSlomo";
            break;
            
        case PHAssetCollectionSubtypeSmartAlbumScreenshots:
            imageName = @"BadgeScreenshots";
            break;
            
        case PHAssetCollectionSubtypeSmartAlbumSelfPortraits:
            imageName = @"BadgeSelfPortraits";
            break;
            
        default:
            imageName = nil;
            break;
    }
    
    if (imageName)
        return [[UIImage ctassetsPickerImageNamed:imageName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    else
        return nil;
}


@end
