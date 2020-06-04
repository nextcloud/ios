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
#import "NSString+TruncateToWidth.h"
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

// mix two image
+ (UIImage *)overlayImage:(UIImage *)backgroundImage watermarkImage:(UIImage *)watermarkImage where:(NSString *)where
{    
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

+ (UIImage *)createNewImageFrom:(NSString *)fileName ocId:(NSString *)ocId filterGrayScale:(BOOL)filterGrayScale typeFile:(NSString *)typeFile writeImage:(BOOL)writeImage
{
    UIImage *originalImage;
    UIImage *scaleImage;
    NSString *fileNamePath = [CCUtility getDirectoryProviderStorageOcId:ocId fileNameView:fileName];
    
    if (![CCUtility fileProviderStorageExists:ocId fileNameView:fileName]) return nil;
    
    // only viedo / image
    if (![typeFile isEqualToString: k_metadataTypeFile_image] && ![typeFile isEqualToString: k_metadataTypeFile_video]) return nil;
    
    if ([typeFile isEqualToString: k_metadataTypeFile_image]) {
        
        originalImage = [UIImage imageWithContentsOfFile:fileNamePath];
    }
    
    if ([typeFile isEqualToString: k_metadataTypeFile_video]) {
        
        // create symbolik link for read video file in temp
        [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:@"tempvideo.mp4"] error:nil];
        [[NSFileManager defaultManager] linkItemAtPath:fileNamePath toPath:[NSTemporaryDirectory() stringByAppendingString:@"tempvideo.mp4"] error:nil];
        
        originalImage = [self generateImageFromVideo:[NSTemporaryDirectory() stringByAppendingString:@"tempvideo.mp4"]];
    }

    scaleImage = [self scaleImage:originalImage toSize:CGSizeMake(k_sizePreview, k_sizePreview) isAspectRation:YES];
    scaleImage = [UIImage imageWithData:UIImageJPEGRepresentation(scaleImage, 0.5f)];
    
    // it is request write photo  ?
    if (writeImage && scaleImage) {
        
        if (filterGrayScale) {
            
            // if it is preview for Upload then trasform it in gray scale
            scaleImage = [self grayscale:scaleImage];
            [UIImagePNGRepresentation(scaleImage) writeToFile:[CCUtility getDirectoryProviderStorageIconOcId:ocId fileNameView:fileName] atomically: YES];
            
        } else {
            
            [UIImagePNGRepresentation(scaleImage) writeToFile:[CCUtility getDirectoryProviderStorageIconOcId:ocId fileNameView:fileName] atomically: YES];
        }
    }
    
    return scaleImage;
}

+ (UIColor *)colorFromHexString:(NSString *)hexString
{
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

+ (UIImage *)changeThemingColorImage:(UIImage *)image multiplier:(NSInteger)multiplier color:(UIColor *)color
{
    CGRect rect = CGRectMake(0, 0, image.size.width*multiplier / (2 / UIScreen.mainScreen.scale), image.size.height*multiplier / (2 / UIScreen.mainScreen.scale));
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClipToMask(context, rect, image.CGImage);
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return [UIImage imageWithCGImage:img.CGImage scale:UIScreen.mainScreen.scale orientation: UIImageOrientationDownMirrored];
}

+ (UIImage *)changeThemingColorImage:(UIImage *)image width:(CGFloat)width height:(CGFloat)height color:(UIColor *)color
{
    CGRect rect = CGRectMake(0, 0, width / (2 / UIScreen.mainScreen.scale), height / (2 / UIScreen.mainScreen.scale));
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClipToMask(context, rect, image.CGImage);
    if (color)
        CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return [UIImage imageWithCGImage:img.CGImage scale:UIScreen.mainScreen.scale orientation: UIImageOrientationDownMirrored];
}

+ (UIImage*)drawText:(NSString*)text inImage:(UIImage*)image colorText:(UIColor *)colorText sizeOfFont:(CGFloat)sizeOfFont
{
    NSDictionary* attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:sizeOfFont], NSForegroundColorAttributeName:colorText};
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    
    int x = image.size.width/2 - attributedString.size.width/2;
    int y = image.size.height/2 - attributedString.size.height/2;
    
    UIGraphicsBeginImageContext(image.size);
    
    [image drawInRect:CGRectMake(0,0,image.size.width,image.size.height)];
    CGRect rect = CGRectMake(x, y, image.size.width, image.size.height);
    [[UIColor whiteColor] set];
    [text drawInRect:CGRectIntegral(rect) withAttributes:attributes];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    newImage = [UIImage imageWithCGImage:newImage.CGImage scale:2 orientation:UIImageOrientationUp];
    
    UIGraphicsEndImageContext();
    
    return newImage;
}

// ------------------------------------------------------------------------------------------------------
// MARK: Blur Image
// ------------------------------------------------------------------------------------------------------

+ (UIImage *)blurryImage:(UIImage *)image withBlurLevel:(CGFloat)blur toSize:(CGSize)toSize
{
    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];
    
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur" keysAndValues:kCIInputImageKey, inputImage, @"inputRadius", @(blur), nil];
    
    CIImage *outputImage = filter.outputImage;
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef outImage = [context createCGImage:outputImage fromRect:[outputImage extent]];
    
    UIImage *blurImage = [UIImage imageWithCGImage:outImage];
    
    return [CCGraphics scaleImage:blurImage toSize:toSize isAspectRation:YES];
}

// ------------------------------------------------------------------------------------------------------
// MARK: Is Light Color
// ------------------------------------------------------------------------------------------------------

/*
Color visibility can be determined according to the following algorithm:

(This is a suggested algorithm that is still open to change.)

Two colors provide good color visibility if the brightness difference and the color difference between the two colors are greater than a set range.

Color brightness is determined by the following formula:
((Red value X 299) + (Green value X 587) + (Blue value X 114)) / 1000
Note: This algorithm is taken from a formula for converting RGB values to YIQ values. This brightness value gives a perceived brightness for a color.

Color difference is determined by the following formula:
(maximum (Red value 1, Red value 2) - minimum (Red value 1, Red value 2)) + (maximum (Green value 1, Green value 2) - minimum (Green value 1, Green value 2)) + (maximum (Blue value 1, Blue value 2) - minimum (Blue value 1, Blue value 2))
*/

+ (BOOL)isLight:(UIColor *)color
{
    const CGFloat *componentColors = CGColorGetComponents(color.CGColor);
    CGFloat colorBrightness = ((componentColors[0] * 299) + (componentColors[1] * 587) + (componentColors[2] * 114)) / 1000;
    
    if (colorBrightness < 0.8) { // STD 0.5
        return false;
    } else {
        return true;
    }
}

+ (UIImage *)grayscale:(UIImage *)sourceImage
{
    /* const UInt8 luminance = (red * 0.2126) + (green * 0.7152) + (blue * 0.0722); // Good luminance value */
    /// Create a gray bitmap context
    const size_t width = (size_t)sourceImage.size.width;
    const size_t height = (size_t)sourceImage.size.height;
    
    const int kNyxNumberOfComponentsPerGreyPixel = 3;
    
    CGRect imageRect = CGRectMake(0, 0, sourceImage.size.width, sourceImage.size.height);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef bmContext = CGBitmapContextCreate(NULL, width, height, 8/*Bits per component*/, width * kNyxNumberOfComponentsPerGreyPixel, colorSpace, kCGImageAlphaNone);
    CGColorSpaceRelease(colorSpace);
    if (!bmContext)
        return nil;
    
    /// Image quality
    CGContextSetShouldAntialias(bmContext, false);
    CGContextSetInterpolationQuality(bmContext, kCGInterpolationHigh);
    
    /// Draw the image in the bitmap context
    CGContextDrawImage(bmContext, imageRect, sourceImage.CGImage);
    
    /// Create an image object from the context
    CGImageRef grayscaledImageRef = CGBitmapContextCreateImage(bmContext);
    UIImage *grayscaled = [UIImage imageWithCGImage:grayscaledImageRef scale:sourceImage.scale orientation:sourceImage.imageOrientation];
    
    /// Cleanup
    CGImageRelease(grayscaledImageRef);
    CGContextRelease(bmContext);
    
    return grayscaled;
}

+ (UIImage *)generateSinglePixelImageWithColor:(UIColor *)color
{
    CGSize imageSize = CGSizeMake(1.0f, 1.0f);
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0.0f);
    
    CGContextRef theContext = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(theContext, color.CGColor);
    CGContextFillRect(theContext, CGRectMake(0.0f, 0.0f, imageSize.width, imageSize.height));
    
    CGImageRef theCGImage = CGBitmapContextCreateImage(theContext);
    UIImage *theImage;
    if ([[UIImage class] respondsToSelector:@selector(imageWithCGImage:scale:orientation:)]) {
        theImage = [UIImage imageWithCGImage:theCGImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    } else {
        theImage = [UIImage imageWithCGImage:theCGImage];
    }
    CGImageRelease(theCGImage);
    
    return theImage;
}

+ (void)addImageToTitle:(NSString *)title colorTitle:(UIColor *)colorTitle imageTitle:(UIImage *)imageTitle imageRight:(BOOL)imageRight navigationItem:(UINavigationItem *)navigationItem
{
    UIView *navView = [UIView new];
    
    UILabel *label = [UILabel new];
    if (imageRight)
        title = [NSString stringWithFormat:@"     %@", title];
    label.text = title;
    [label sizeToFit];
    label.center = navView.center;
    label.textColor = colorTitle;
    label.textAlignment = NSTextAlignmentCenter;
    
    CGFloat correct = 6;
    UIImageView *image = [UIImageView new];
    image.image = imageTitle;
    CGFloat imageAspect = image.image.size.width/image.image.size.height;
    
    if (imageRight) {
        image.frame = CGRectMake(label.intrinsicContentSize.width+label.frame.origin.x+correct, label.frame.origin.y+correct/2, label.frame.size.height*imageAspect-correct, label.frame.size.height-correct);
    } else {
        image.frame = CGRectMake(label.frame.origin.x-label.frame.size.height*imageAspect, label.frame.origin.y+correct/2, label.frame.size.height*imageAspect-correct, label.frame.size.height-correct);
    }
    
    image.contentMode = UIViewContentModeScaleAspectFit;
    
    [navView addSubview:label];
    [navView addSubview:image];
    
    navigationItem.titleView = navView;
    [navView sizeToFit];
}

+ (void)settingThemingColor:(NSString *)themingColor themingColorElement:(NSString *)themingColorElement themingColorText:(NSString *)themingColorText
{
    UIColor *newColor, *newColorElement, *newColorText;
    
    // COLOR
    if (themingColor.length == 7) {
        newColor = [CCGraphics colorFromHexString:themingColor];
    } else {
        newColor = NCBrandColor.sharedInstance.customer;
    }
            
    // COLOR TEXT
    if (themingColorText.length == 7) {
        newColorText = [CCGraphics colorFromHexString:themingColorText];
    } else {
        newColorText = NCBrandColor.sharedInstance.customerText;
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
            
    NCBrandColor.sharedInstance.brand = newColor;
    NCBrandColor.sharedInstance.brandElement = newColorElement;
    NCBrandColor.sharedInstance.brandText = newColorText;
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

