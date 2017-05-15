//
//  CCGraphics.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/02/16.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

#import "AppDelegate.h"
#import "CCUtility.h"
#import "NSString+TruncateToWidth.h"

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

// mix two image
+ (UIImage *)overlayImage:(UIImage *)backgroundImage watermarkImage:(UIImage *)watermarkImage where:(NSString *)where
{
    // example watermarkImage = [UIImage imageNamed:@"lock"];
    
    UIGraphicsBeginImageContext(backgroundImage.size);
    [backgroundImage drawInRect:CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height)];
    
    if ([where isEqualToString:@"right"]) [watermarkImage drawInRect:CGRectMake(backgroundImage.size.width - watermarkImage.size.width, backgroundImage.size.height - watermarkImage.size.height, watermarkImage.size.width, watermarkImage.size.height)];
    
    if ([where isEqualToString:@"left"]) [watermarkImage drawInRect:CGRectMake(0, backgroundImage.size.height - watermarkImage.size.height, backgroundImage.size.width - watermarkImage.size.width, backgroundImage.size.height - watermarkImage.size.height)];
    
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
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

+ (UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)targetSize
{
    //If scaleFactor is not touched, no scaling will occur
    CGFloat scaleFactor = 1.0;
    
    //Deciding which factor to use to scale the image (factor = targetSize / imageSize)
    if (image.size.width > targetSize.width || image.size.height > targetSize.height)
        if (!((scaleFactor = (targetSize.width / image.size.width)) > (targetSize.height / image.size.height))) //scale to fit width, or
            scaleFactor = targetSize.height / image.size.height; // scale to fit heigth.
    
    UIGraphicsBeginImageContext(targetSize);
    
    //Creating the rect where the scaled image is drawn in
    CGRect rect = CGRectMake((targetSize.width - image.size.width * scaleFactor) / 2,
                             (targetSize.height -  image.size.height * scaleFactor) / 2,
                             image.size.width * scaleFactor, image.size.height * scaleFactor);
    
    //Draw the image into the rect
    [image drawInRect:rect];
    
    //Saving the image, ending image context
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
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
    
    UIGraphicsBeginImageContextWithOptions(sz, NO, scale);
    [image drawInRect:CGRectMake(0, 0, sz.width, sz.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}


+ (UIImage *)createNewImageFrom:(NSString *)fileName directoryUser:(NSString *)directoryUser fileNameTo:(NSString *)fileNameTo fileNamePrint:(NSString *)fileNamePrint size:(NSString *)size imageForUpload:(BOOL)imageForUpload typeFile:(NSString *)typeFile writePreview:(BOOL)writePreview optimizedFileName:(BOOL)optimizedFileName
{
    UIImage *originalImage;
    UIImage *scaleImage;
    CGRect rect;
    CGFloat width, height;
    
    NSString *ext = [[fileNamePrint pathExtension] lowercaseString];
    
    if ([[directoryUser substringFromIndex: [directoryUser length] - 1] isEqualToString:@"/"]) directoryUser = [directoryUser substringToIndex:[directoryUser length]-1];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileName]]) return nil;
    
    // only viedo / image
    if (![typeFile isEqualToString: k_metadataTypeFile_image] && ![typeFile isEqualToString: k_metadataTypeFile_video]) return nil;
    
    if ([typeFile isEqualToString: k_metadataTypeFile_image]) {
        
        originalImage = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", directoryUser, fileName]];
    }
    
    if ([typeFile isEqualToString: k_metadataTypeFile_video]) {
        
        // create symbolik link for read video file in temp
        [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:@"tempvideo.mp4"] error:nil];
        [[NSFileManager defaultManager] linkItemAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileName] toPath:[NSTemporaryDirectory() stringByAppendingString:@"tempvideo.mp4"] error:nil];
        
        originalImage = [self generateImageFromVideo:[NSTemporaryDirectory() stringByAppendingString:@"tempvideo.mp4"]];
    }
    
    if ([size isEqualToString:@"xs"]) scaleImage = [self scaleImage:originalImage toSize:CGSizeMake(32, 32)];
    if ([size isEqualToString:@"s"]) scaleImage = [self scaleImage:originalImage toSize:CGSizeMake(64, 64)];
    if ([size isEqualToString:@"m"]) scaleImage = [self scaleImage:originalImage toSize:CGSizeMake(128, 128)];
    if ([size isEqualToString:@"l"]) scaleImage = [self scaleImage:originalImage toSize:CGSizeMake(640, 640)];
    if ([size isEqualToString:@"xl"]) scaleImage = [self scaleImage:originalImage toSize:CGSizeMake(1024, 1024)];
    
    scaleImage = [UIImage imageWithData:UIImageJPEGRepresentation(scaleImage, 0.5f)];
    
    // it is request write photo preview ?
    if (writePreview && scaleImage) {
        
        if (imageForUpload) {
            
            // write image preview in tmp for plist
            [self saveIcoWithFileID:fileNameTo image:scaleImage writeToFile:[NSTemporaryDirectory() stringByAppendingString:fileNameTo] copy:NO move:NO fromPath:nil toPath:nil];
            
            // if it is preview for Upload then trasform it in gray scale
            //TODO: Crash with swift
            scaleImage = [scaleImage grayscale];
            [self saveIcoWithFileID:fileNameTo image:scaleImage writeToFile:[NSString stringWithFormat:@"%@/%@.ico", directoryUser, fileNameTo] copy:NO move:NO fromPath:nil toPath:nil];
            
        } else {
            
            [self saveIcoWithFileID:fileNameTo image:scaleImage writeToFile:[NSString stringWithFormat:@"%@/%@.ico", directoryUser, fileNameTo] copy:NO move:NO fromPath:nil toPath:nil];
        }
    }
    
    // Optimized photos resolution
    // Resize image 640 x 480 ( with proportion : 1,333)
    if (originalImage.size.height < originalImage.size.width) {
        
        // (lanscape)
        
        width = 640;
        height = 480;
        
    } else {
        
        // (portrait)
        
        height = 640;
        width = 480;
    }
    
    // Optimized photos resolution
    if ([typeFile isEqualToString: k_metadataTypeFile_image] && [ext isEqualToString:@"gif"] == NO && optimizedFileName && scaleImage && (originalImage.size.width > width || originalImage.size.height > height)) {
        
        // conversion scale proportion
        if (height > width) {
            
            float proportion = originalImage.size.height / originalImage.size.width;
            width = height / proportion;
            
        } else {
            
            float proportion = originalImage.size.width / originalImage.size.height;
            height = width / proportion;
        }
        
        rect = CGRectMake(0,0,width,height);
        
        UIGraphicsBeginImageContext(rect.size);
        [originalImage drawInRect:rect];
        UIImage *resizeImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        resizeImage = [UIImage imageWithData:UIImageJPEGRepresentation(resizeImage, 0.5f)];
        if (resizeImage) [UIImagePNGRepresentation(resizeImage) writeToFile:[NSString stringWithFormat:@"%@/%@", directoryUser, fileNameTo] atomically: YES];
    }
    
    return scaleImage;
}

+ (void)saveIcoWithFileID:(NSString *)fileID image:(UIImage *)image writeToFile:(NSString *)writeToFile copy:(BOOL)copy move:(BOOL)move fromPath:(NSString *)fromPath toPath:(NSString *)toPath
{
    if (writeToFile)
        [UIImagePNGRepresentation(image) writeToFile:writeToFile atomically: YES];

    if (copy)
        [CCUtility copyFileAtPath:fromPath toPath:toPath];

    if (move)
        [[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:nil];

#ifndef EXTENSION
    if (image && fileID)
        [app.icoImagesCache setObject:image forKey:fileID];
#endif
}

+ (UIColor *)colorFromHexString:(NSString *)hexString
{
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

+ (UIImage *)changeThemingColorImage:(UIImage *)image color:(UIColor *)color
{
    CGRect rect = CGRectMake(0, 0, image.size.width*2, image.size.height*2);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClipToMask(context, rect, image.CGImage);
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return [UIImage imageWithCGImage:img.CGImage scale:2.0 orientation: UIImageOrientationDownMirrored];
}

@end

// ------------------------------------------------------------------------------------------------------
// MARK: Avatar
// ------------------------------------------------------------------------------------------------------

@implementation CCAvatar

- (id)initWithImage:(UIImage *)image borderColor:(UIColor*)borderColor borderWidth:(float)borderWidth
{
    self = [super initWithImage:image];
    
    float cornerRadius = self.frame.size.height/2.0f;
    CALayer *layer = [self layer];
        
    [layer setMasksToBounds:YES];
    [layer setCornerRadius: cornerRadius];
    [layer setBorderWidth: borderWidth];
    [layer setBorderColor:[borderColor CGColor]];
    
    return self;
}

@end

