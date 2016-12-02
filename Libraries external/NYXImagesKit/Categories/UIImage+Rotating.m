//
//  UIImage+Rotation.m
//  NYXImagesKit
//
//  Created by @Nyx0uf on 02/05/11.
//  Copyright 2012 Nyx0uf. All rights reserved.
//  www.cocoaintheshell.com
//


#import "UIImage+Rotating.h"
#import <QuartzCore/QuartzCore.h>
#import <Accelerate/Accelerate.h>

@implementation UIImage (NYX_Rotating)

-(UIImage*)rotateInRadians:(CGFloat)radians flipOverHorizontalAxis:(BOOL)doHorizontalFlip verticalAxis:(BOOL)doVerticalFlip
{
	/// Create an ARGB bitmap context
	const size_t width = (size_t)CGImageGetWidth(self.CGImage);
	const size_t height = (size_t)CGImageGetHeight(self.CGImage);

	CGRect rotatedRect = CGRectApplyAffineTransform(CGRectMake(0., 0., width, height), CGAffineTransformMakeRotation(radians));

	CGContextRef bmContext = NYXCreateARGBBitmapContext((size_t)rotatedRect.size.width, (size_t)rotatedRect.size.height, (size_t)rotatedRect.size.width * kNyxNumberOfComponentsPerARBGPixel);
	if (!bmContext)
		return nil;

	/// Image quality
	CGContextSetShouldAntialias(bmContext, true);
	CGContextSetAllowsAntialiasing(bmContext, true);
	CGContextSetInterpolationQuality(bmContext, kCGInterpolationHigh);

	/// Rotation happen here (around the center)
	CGContextTranslateCTM(bmContext, +(rotatedRect.size.width / 2.0f), +(rotatedRect.size.height / 2.0f));
	CGContextRotateCTM(bmContext, radians);

  // Do flips
	CGContextTranslateCTM(bmContext, (doHorizontalFlip ? width : 0.0f), (doVerticalFlip ? height : 0.0f));
	CGContextScaleCTM(bmContext, (doHorizontalFlip ? -1.0f : 1.0f), (doVerticalFlip ? -1.0f : 1.0f));

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, CGRectMake(-(width / 2.0f), -(height / 2.0f), width, height), self.CGImage);

	/// Create an image object from the context
	CGImageRef resultImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* resultImage = [UIImage imageWithCGImage:resultImageRef scale:self.scale orientation:self.imageOrientation];

	/// Cleanup
	CGImageRelease(resultImageRef);
	CGContextRelease(bmContext);

	return resultImage;
}

-(UIImage*)rotateInRadians:(float)radians
{
  return [self rotateInRadians:radians flipOverHorizontalAxis:NO verticalAxis:NO];
}

-(UIImage*)rotateInDegrees:(float)degrees
{
	return [self rotateInRadians:(float)NYX_DEGREES_TO_RADIANS(degrees)];
}

-(UIImage*)verticalFlip
{
	return [self rotateInRadians:0. flipOverHorizontalAxis:NO verticalAxis:YES];
}

-(UIImage*)horizontalFlip
{
  return [self rotateInRadians:0. flipOverHorizontalAxis:YES verticalAxis:NO];
}

-(UIImage*)rotateImagePixelsInRadians:(float)radians
{
	/// Create an ARGB bitmap context
	const size_t width = (size_t)(self.size.width * self.scale);
	const size_t height = (size_t)(self.size.height * self.scale);
	const size_t bytesPerRow = width * kNyxNumberOfComponentsPerARBGPixel;
	CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, bytesPerRow);
	if (!bmContext)
		return nil;

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, CGRectMake(0.0f, 0.0f, width, height), self.CGImage);

	/// Grab the image raw data
	UInt8* data = (UInt8*)CGBitmapContextGetData(bmContext);
	if (!data)
	{
		CGContextRelease(bmContext);
		return nil;
	}

	vImage_Buffer src = {data, height, width, bytesPerRow};
	vImage_Buffer dest = {data, height, width, bytesPerRow};
	Pixel_8888 bgColor = {0, 0, 0, 0};
	vImageRotate_ARGB8888(&src, &dest, NULL, radians, bgColor, kvImageBackgroundColorFill);

	CGImageRef rotatedImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* rotated = [UIImage imageWithCGImage:rotatedImageRef scale:self.scale orientation:self.imageOrientation];

	/// Cleanup
	CGImageRelease(rotatedImageRef);
	CGContextRelease(bmContext);

	return rotated;
}

-(UIImage*)rotateImagePixelsInDegrees:(float)degrees
{
	return [self rotateImagePixelsInRadians:(float)NYX_DEGREES_TO_RADIANS(degrees)];
}

@end
