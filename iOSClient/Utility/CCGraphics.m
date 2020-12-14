//
//  CCGraphics.m
//  Nextcloud
//
//  Created by Marino Faggiana on 04/02/16.
//  Copyright (c) 2016 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "CCGraphics.h"
#import "CCUtility.h"
#import "NCBridgeSwift.h"

@implementation CCGraphics

+ (UIImage *)thumbnailImageForVideo:(NSURL *)videoURL atTime:(NSTimeInterval)time
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    NSParameterAssert(asset);
    AVAssetImageGenerator *assetIG =
    [[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetIG.appliesPreferredTrackTransform = YES;
    assetIG.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    
    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = time;
    NSError *igError = nil;
    thumbnailImageRef =
    [assetIG copyCGImageAtTime:CMTimeMake(thumbnailImageTime, 60) actualTime:NULL error:&igError];
    
    if (!thumbnailImageRef) NSLog(@"[LOG] thumbnailImageGenerationError %@", igError );
    
    UIImage *thumbnailImage = thumbnailImageRef ? [[UIImage alloc] initWithCGImage:thumbnailImageRef] : nil;
    
    return thumbnailImage;
}

+ (UIImage *)generateImageFromVideo:(NSString *)videoPath
{
    NSURL *url = [NSURL fileURLWithPath:videoPath];
    NSError *error = NULL;

    AVURLAsset* asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetImageGenerator* imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    // CMTime time = CMTimeMake(1, 65);
    CGImageRef cgImage = [imageGenerator copyCGImageAtTime:CMTimeMake(0, 1) actualTime:nil error:&error];
    if(error) return nil;
    UIImage* image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return image;
}

+ (UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)targetSize isAspectRation:(BOOL)aspect
{
    CGFloat originRatio = image.size.width / image.size.height;
    CGFloat newRatio = targetSize.width / targetSize.height;
    CGSize sz;
    CGFloat scale = 1.0;
    
    if (!aspect) {
        sz = targetSize;
    }else {
        if (originRatio < newRatio) {
            sz.height = targetSize.height;
            sz.width = targetSize.height * originRatio;
        }else {
            sz.width = targetSize.width;
            sz.height = targetSize.width / originRatio;
        }
    }
    
    sz.width /= scale;
    sz.height /= scale;
    
    UIGraphicsBeginImageContextWithOptions(sz, NO, UIScreen.mainScreen.scale);
    [image drawInRect:CGRectMake(0, 0, sz.width, sz.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

+ (void)createNewImageFrom:(NSString *)fileName ocId:(NSString *)ocId etag:(NSString *)etag typeFile:(NSString *)typeFile
{
    UIImage *originalImage;
    UIImage *scaleImagePreview;
    UIImage *scaleImageIcon;
    NSString *fileNamePath = [CCUtility getDirectoryProviderStorageOcId:ocId fileNameView:fileName];
    NSString *fileNamePathPreview = [CCUtility getDirectoryProviderStoragePreviewOcId:ocId etag:etag];
    NSString *fileNamePathIcon = [CCUtility getDirectoryProviderStorageIconOcId:ocId etag:etag];

    if (![CCUtility fileProviderStorageExists:ocId fileNameView:fileName]) return;
    
    // only viedo / image
    if (![typeFile isEqualToString: NCBrandGlobal.shared.metadataTypeFileImage] && ![typeFile isEqualToString: NCBrandGlobal.shared.metadataTypeFileVideo]) return;
    
    if ([typeFile isEqualToString: NCBrandGlobal.shared.metadataTypeFileImage]) {
        
        originalImage = [UIImage imageWithContentsOfFile:fileNamePath];
        if (originalImage == nil) { return; }
    }
    
    if ([typeFile isEqualToString: NCBrandGlobal.shared.metadataTypeFileVideo]) {
        
        // create symbolik link for read video file in temp
        [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:@"tempvideo.mp4"] error:nil];
        [[NSFileManager defaultManager] linkItemAtPath:fileNamePath toPath:[NSTemporaryDirectory() stringByAppendingString:@"tempvideo.mp4"] error:nil];
        
        originalImage = [self generateImageFromVideo:[NSTemporaryDirectory() stringByAppendingString:@"tempvideo.mp4"]];
    }

    scaleImagePreview = [self scaleImage:originalImage toSize:CGSizeMake(NCBrandGlobal.shared.sizePreview, NCBrandGlobal.shared.sizePreview) isAspectRation:YES];
    scaleImageIcon = [self scaleImage:originalImage toSize:CGSizeMake(NCBrandGlobal.shared.sizeIcon, NCBrandGlobal.shared.sizeIcon) isAspectRation:YES];

    scaleImagePreview = [UIImage imageWithData:UIImageJPEGRepresentation(scaleImagePreview, 0.5f)];
    scaleImageIcon = [UIImage imageWithData:UIImageJPEGRepresentation(scaleImageIcon, 0.5f)];
    
    // it is request write photo  ?
    if (scaleImagePreview && scaleImageIcon) {
                    
        [UIImageJPEGRepresentation(scaleImagePreview, 0.5) writeToFile:fileNamePathPreview atomically:true];
        [UIImageJPEGRepresentation(scaleImageIcon, 0.5) writeToFile:fileNamePathIcon atomically:true];
    }
    
    return;
}

+ (UIColor *)colorFromHexString:(NSString *)hexString
{
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

+ (void)settingThemingColor:(NSString *)themingColor themingColorElement:(NSString *)themingColorElement themingColorText:(NSString *)themingColorText
{
    UIColor *newColor, *newColorElement, *newColorText;
    
    // COLOR
    if (themingColor.length == 7) {
        newColor = [CCGraphics colorFromHexString:themingColor];
    } else {
        newColor = NCBrandColor.shared.customer;
    }
            
    // COLOR TEXT
    if (themingColorText.length == 7) {
        newColorText = [CCGraphics colorFromHexString:themingColorText];
    } else {
        newColorText = NCBrandColor.shared.customerText;
    }
            
    // COLOR ELEMENT
    if (themingColorElement.length == 7) {
        newColorElement = [CCGraphics colorFromHexString:themingColorElement];
    } else {
        if ([themingColorText isEqualToString:@"#000000"])
            newColorElement = [UIColor blackColor];
        else
            newColorElement = newColor;
    }
            
    NCBrandColor.shared.brand = newColor;
    NCBrandColor.shared.brandElement = newColorElement;
    NCBrandColor.shared.brandText = newColorText;
}

@end
