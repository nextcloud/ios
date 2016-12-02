//
//  UIImage+Filters.m
//  NYXImagesKit
//
//  Created by @Nyx0uf on 02/05/11.
//  Copyright 2012 Nyx0uf. All rights reserved.
//  www.cocoaintheshell.com
//


#import "UIImage+Filtering.h"
#import <CoreImage/CoreImage.h>
#import <Accelerate/Accelerate.h>


/* Sepia values for manual filtering (< iOS 5) */
static float const __sepiaFactorRedRed = 0.393f;
static float const __sepiaFactorRedGreen = 0.349f;
static float const __sepiaFactorRedBlue = 0.272f;
static float const __sepiaFactorGreenRed = 0.769f;
static float const __sepiaFactorGreenGreen = 0.686f;
static float const __sepiaFactorGreenBlue = 0.534f;
static float const __sepiaFactorBlueRed = 0.189f;
static float const __sepiaFactorBlueGreen = 0.168f;
static float const __sepiaFactorBlueBlue = 0.131f;

/* Negative multiplier to invert a number */
static float __negativeMultiplier = -1.0f;

#pragma mark - Edge detection kernels
/* vImage kernel */
/*static int16_t __s_edgedetect_kernel_3x3[9] = {
	-1, -1, -1, 
	-1, 8, -1, 
	-1, -1, -1
};*/
/* vDSP kernel */
static float __f_edgedetect_kernel_3x3[9] = {
	-1.0f, -1.0f, -1.0f, 
	-1.0f, 8.0f, -1.0f, 
	-1.0f, -1.0f, -1.0f
};

#pragma mark - Emboss kernels
/* vImage kernel */
static int16_t __s_emboss_kernel_3x3[9] = {
	-2, 0, 0, 
	0, 1, 0, 
	0, 0, 2
};

#pragma mark - Sharpen kernels
/* vImage kernel */
static int16_t __s_sharpen_kernel_3x3[9] = {
	-1, -1, -1, 
	-1, 9, -1, 
	-1, -1, -1
};

#pragma mark - Unsharpen kernels
/* vImage kernel */
static int16_t __s_unsharpen_kernel_3x3[9] = {
	-1, -1, -1, 
	-1, 17, -1, 
	-1, -1, -1
};


@implementation UIImage (NYX_Filtering)

// Value should be in the range (-255, 255)
-(UIImage*)brightenWithValue:(float)value
{
	/// Create an ARGB bitmap context
	const size_t width = (size_t)self.size.width;
	const size_t height = (size_t)self.size.height;
	CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, width * kNyxNumberOfComponentsPerARBGPixel);
	if (!bmContext) 
		return nil;

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, self.CGImage); 

	/// Grab the image raw data
	UInt8* data = (UInt8*)CGBitmapContextGetData(bmContext);
	if (!data)
	{
		CGContextRelease(bmContext);
		return nil;
	}

	const size_t pixelsCount = width * height;
	float* dataAsFloat = (float*)malloc(sizeof(float) * pixelsCount);
	float min = (float)kNyxMinPixelComponentValue, max = (float)kNyxMaxPixelComponentValue;

	/// Calculate red components
	vDSP_vfltu8(data + 1, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsadd(dataAsFloat, 1, &value, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, data + 1, 4, pixelsCount);

	/// Calculate green components
	vDSP_vfltu8(data + 2, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsadd(dataAsFloat, 1, &value, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, data + 2, 4, pixelsCount);

	/// Calculate blue components
	vDSP_vfltu8(data + 3, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsadd(dataAsFloat, 1, &value, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, data + 3, 4, pixelsCount);

	CGImageRef brightenedImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* brightened = [UIImage imageWithCGImage:brightenedImageRef scale:self.scale orientation:self.imageOrientation];

	/// Cleanup
	CGImageRelease(brightenedImageRef);
	free(dataAsFloat);
	CGContextRelease(bmContext);

	return brightened;
}

/// (-255, 255)
-(UIImage*)contrastAdjustmentWithValue:(float)value
{
	/// Create an ARGB bitmap context
	const size_t width = (size_t)self.size.width;
	const size_t height = (size_t)self.size.height;
	CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, width * kNyxNumberOfComponentsPerARBGPixel);
	if (!bmContext) 
		return nil;

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, self.CGImage);

	/// Grab the image raw data
	UInt8* data = (UInt8*)CGBitmapContextGetData(bmContext);
	if (!data)
	{
		CGContextRelease(bmContext);
		return nil;
	}

	const size_t pixelsCount = width * height;
	float* dataAsFloat = (float*)malloc(sizeof(float) * pixelsCount);
	float min = (float)kNyxMinPixelComponentValue, max = (float)kNyxMaxPixelComponentValue;

	/// Contrast correction factor
	const float factor = (259.0f * (value + 255.0f)) / (255.0f * (259.0f - value));

	float v1 = -128.0f, v2 = 128.0f;

	/// Calculate red components
	vDSP_vfltu8(data + 1, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsadd(dataAsFloat, 1, &v1, dataAsFloat, 1, pixelsCount);
	vDSP_vsmul(dataAsFloat, 1, &factor, dataAsFloat, 1, pixelsCount);
	vDSP_vsadd(dataAsFloat, 1, &v2, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, data + 1, 4, pixelsCount);

	/// Calculate green components
	vDSP_vfltu8(data + 2, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsadd(dataAsFloat, 1, &v1, dataAsFloat, 1, pixelsCount);
	vDSP_vsmul(dataAsFloat, 1, &factor, dataAsFloat, 1, pixelsCount);
	vDSP_vsadd(dataAsFloat, 1, &v2, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, data + 2, 4, pixelsCount);

	/// Calculate blue components
	vDSP_vfltu8(data + 3, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsadd(dataAsFloat, 1, &v1, dataAsFloat, 1, pixelsCount);
	vDSP_vsmul(dataAsFloat, 1, &factor, dataAsFloat, 1, pixelsCount);
	vDSP_vsadd(dataAsFloat, 1, &v2, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, data + 3, 4, pixelsCount);

	/// Create an image object from the context
	CGImageRef contrastedImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* contrasted = [UIImage imageWithCGImage:contrastedImageRef scale:self.scale orientation:self.imageOrientation];

	/// Cleanup
	CGImageRelease(contrastedImageRef);
	free(dataAsFloat);
	CGContextRelease(bmContext);

	return contrasted;
}

-(UIImage*)edgeDetectionWithBias:(NSInteger)bias
{
#pragma unused(bias)
	/// Create an ARGB bitmap context
	const size_t width = (size_t)self.size.width;
	const size_t height = (size_t)self.size.height;
	const size_t bytesPerRow = width * kNyxNumberOfComponentsPerARBGPixel;
	CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, bytesPerRow);
	if (!bmContext) 
		return nil;

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, self.CGImage); 

	/// Grab the image raw data
	UInt8* data = (UInt8*)CGBitmapContextGetData(bmContext);
	if (!data)
	{
		CGContextRelease(bmContext);
		return nil;
	}

	/// vImage (iOS 5) works on simulator but not on device
	/*if ((&vImageConvolveWithBias_ARGB8888))
	{
		const size_t n = sizeof(UInt8) * width * height * 4;
		void* outt = malloc(n);
		vImage_Buffer src = {data, height, width, bytesPerRow};
		vImage_Buffer dest = {outt, height, width, bytesPerRow};

		vImageConvolveWithBias_ARGB8888(&src, &dest, NULL, 0, 0, __s_edgedetect_kernel_3x3, 3, 3, 1, bias, NULL, kvImageCopyInPlace);

		CGDataProviderRef dp = CGDataProviderCreateWithData(NULL, data, n, NULL);

		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
		CGImageRef edgedImageRef = CGImageCreate(width, height, 8, 32, bytesPerRow, cs, kCGBitmapByteOrderDefault | kCGImageAlphaNoneSkipFirst, dp, NULL, true, kCGRenderingIntentDefault);
		CGColorSpaceRelease(cs);

		//memcpy(data, outt, n);
		//CGImageRef edgedImageRef = CGBitmapContextCreateImage(bmContext);
		UIImage* edged = [UIImage imageWithCGImage:edgedImageRef];

		/// Cleanup
		CGImageRelease(edgedImageRef);
		CGDataProviderRelease(dp);
		free(outt);
		CGContextRelease(bmContext);

		return edged;
	}
	else
	{*/
		const size_t pixelsCount = width * height;
		const size_t n = sizeof(float) * pixelsCount;
		float* dataAsFloat = malloc(n);
		float* resultAsFloat = malloc(n);
		float min = (float)kNyxMinPixelComponentValue, max = (float)kNyxMaxPixelComponentValue;

		/// Red components
		vDSP_vfltu8(data + 1, 4, dataAsFloat, 1, pixelsCount);
		vDSP_f3x3(dataAsFloat, height, width, __f_edgedetect_kernel_3x3, resultAsFloat);
		vDSP_vclip(resultAsFloat, 1, &min, &max, resultAsFloat, 1, pixelsCount);
		vDSP_vfixu8(resultAsFloat, 1, data + 1, 4, pixelsCount);

		/// Green components
		vDSP_vfltu8(data + 2, 4, dataAsFloat, 1, pixelsCount);
		vDSP_f3x3(dataAsFloat, height, width, __f_edgedetect_kernel_3x3, resultAsFloat);
		vDSP_vclip(resultAsFloat, 1, &min, &max, resultAsFloat, 1, pixelsCount);
		vDSP_vfixu8(resultAsFloat, 1, data + 2, 4, pixelsCount);

		/// Blue components
		vDSP_vfltu8(data + 3, 4, dataAsFloat, 1, pixelsCount);
		vDSP_f3x3(dataAsFloat, height, width, __f_edgedetect_kernel_3x3, resultAsFloat);
		vDSP_vclip(resultAsFloat, 1, &min, &max, resultAsFloat, 1, pixelsCount);
		vDSP_vfixu8(resultAsFloat, 1, data + 3, 4, pixelsCount);

		CGImageRef edgedImageRef = CGBitmapContextCreateImage(bmContext);
		UIImage* edged = [UIImage imageWithCGImage:edgedImageRef];

		/// Cleanup
		CGImageRelease(edgedImageRef);
		free(resultAsFloat);
		free(dataAsFloat);
		CGContextRelease(bmContext);

		return edged;
	//}
}

-(UIImage*)embossWithBias:(NSInteger)bias
{
	/// Create an ARGB bitmap context
	const size_t width = (size_t)self.size.width;
	const size_t height = (size_t)self.size.height;
	const size_t bytesPerRow = width * kNyxNumberOfComponentsPerARBGPixel;
	CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, bytesPerRow);
	if (!bmContext) 
		return nil;

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, self.CGImage); 

	/// Grab the image raw data
	UInt8* data = (UInt8*)CGBitmapContextGetData(bmContext);
	if (!data)
	{
		CGContextRelease(bmContext);
		return nil;
	}

	const size_t n = sizeof(UInt8) * width * height * 4;
	void* outt = malloc(n);
	vImage_Buffer src = {data, height, width, bytesPerRow};
	vImage_Buffer dest = {outt, height, width, bytesPerRow};
	vImageConvolveWithBias_ARGB8888(&src, &dest, NULL, 0, 0, __s_emboss_kernel_3x3, 3, 3, 1/*divisor*/, (int)bias, NULL, kvImageCopyInPlace);
	
	memcpy(data, outt, n);
	
	free(outt);

	CGImageRef embossImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* emboss = [UIImage imageWithCGImage:embossImageRef];

	/// Cleanup
	CGImageRelease(embossImageRef);
	CGContextRelease(bmContext);

	return emboss;
}

/// (0.01, 8)
-(UIImage*)gammaCorrectionWithValue:(float)value
{
	const size_t width = (size_t)self.size.width;
	const size_t height = (size_t)self.size.height;
	/// Number of bytes per row, each pixel in the bitmap will be represented by 4 bytes (ARGB), 8 bits of alpha/red/green/blue
	const size_t bytesPerRow = width * kNyxNumberOfComponentsPerARBGPixel;

	/// Create an ARGB bitmap context
	CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, bytesPerRow);
	if (!bmContext) 
		return nil;

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, self.CGImage);

	/// Grab the image raw data
	UInt8* data = (UInt8*)CGBitmapContextGetData(bmContext);
	if (!data)
	{
		CGContextRelease(bmContext);
		return nil;
	}

	const size_t pixelsCount = width * height;
	const size_t n = sizeof(float) * pixelsCount;
	float* dataAsFloat = (float*)malloc(n);
	float* temp = (float*)malloc(n);
	float min = (float)kNyxMinPixelComponentValue, max = (float)kNyxMaxPixelComponentValue;
	const int iPixels = (int)pixelsCount;
	
	/// Need a vector with same size :(
	vDSP_vfill(&value, temp, 1, pixelsCount);
	
	/// Calculate red components
	vDSP_vfltu8(data + 1, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsdiv(dataAsFloat, 1, &max, dataAsFloat, 1, pixelsCount);
	vvpowf(dataAsFloat, temp, dataAsFloat, &iPixels);
	vDSP_vsmul(dataAsFloat, 1, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, data + 1, 4, pixelsCount);
	
	/// Calculate green components
	vDSP_vfltu8(data + 2, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsdiv(dataAsFloat, 1, &max, dataAsFloat, 1, pixelsCount);
	vvpowf(dataAsFloat, temp, dataAsFloat, &iPixels);
	vDSP_vsmul(dataAsFloat, 1, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, data + 2, 4, pixelsCount);
	
	/// Calculate blue components
	vDSP_vfltu8(data + 3, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsdiv(dataAsFloat, 1, &max, dataAsFloat, 1, pixelsCount);
	vvpowf(dataAsFloat, temp, dataAsFloat, &iPixels);
	vDSP_vsmul(dataAsFloat, 1, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, data + 3, 4, pixelsCount);
	
	/// Cleanup
	free(temp);
	free(dataAsFloat);

	/// Create an image object from the context
	CGImageRef gammaImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* gamma = [UIImage imageWithCGImage:gammaImageRef];

	/// Cleanup
	CGImageRelease(gammaImageRef);
	CGContextRelease(bmContext);

	return gamma;
}

-(UIImage*)grayscale
{
	/* const UInt8 luminance = (red * 0.2126) + (green * 0.7152) + (blue * 0.0722); // Good luminance value */
	/// Create a gray bitmap context
	const size_t width = (size_t)self.size.width;
	const size_t height = (size_t)self.size.height;
    
    CGRect imageRect = CGRectMake(0, 0, self.size.width, self.size.height);
    
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
	CGContextRef bmContext = CGBitmapContextCreate(NULL, width, height, 8/*Bits per component*/, width * kNyxNumberOfComponentsPerGreyPixel, colorSpace, kCGImageAlphaNone);
	CGColorSpaceRelease(colorSpace);
	if (!bmContext)
		return nil;

	/// Image quality
	CGContextSetShouldAntialias(bmContext, false);
	CGContextSetInterpolationQuality(bmContext, kCGInterpolationHigh);

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, imageRect, self.CGImage);

	/// Create an image object from the context
	CGImageRef grayscaledImageRef = CGBitmapContextCreateImage(bmContext);
    UIImage *grayscaled = [UIImage imageWithCGImage:grayscaledImageRef scale:self.scale orientation:self.imageOrientation];
        
	/// Cleanup
	CGImageRelease(grayscaledImageRef);
	CGContextRelease(bmContext);

	return grayscaled;
}

-(UIImage*)invert
{
	/// Create an ARGB bitmap context
	const size_t width = (size_t)self.size.width;
	const size_t height = (size_t)self.size.height;
	CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, width * kNyxNumberOfComponentsPerARBGPixel);
	if (!bmContext) 
		return nil;

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, self.CGImage); 

	/// Grab the image raw data
	UInt8* data = (UInt8*)CGBitmapContextGetData(bmContext);
	if (!data)
	{
		CGContextRelease(bmContext);
		return nil;
	}

	const size_t pixelsCount = width * height;
	float* dataAsFloat = (float*)malloc(sizeof(float) * pixelsCount);
	float min = (float)kNyxMinPixelComponentValue, max = (float)kNyxMaxPixelComponentValue;
	UInt8* dataRed = data + 1;
	UInt8* dataGreen = data + 2;
	UInt8* dataBlue = data + 3;

	/// vDSP_vsmsa() = multiply then add
	/// slightly faster than the couple vDSP_vneg() & vDSP_vsadd()
	/// Probably because there are 3 function calls less

	/// Calculate red components
	vDSP_vfltu8(dataRed, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsmsa(dataAsFloat, 1, &__negativeMultiplier, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, dataRed, 4, pixelsCount);

	/// Calculate green components
	vDSP_vfltu8(dataGreen, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsmsa(dataAsFloat, 1, &__negativeMultiplier, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, dataGreen, 4, pixelsCount);

	/// Calculate blue components
	vDSP_vfltu8(dataBlue, 4, dataAsFloat, 1, pixelsCount);
	vDSP_vsmsa(dataAsFloat, 1, &__negativeMultiplier, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vclip(dataAsFloat, 1, &min, &max, dataAsFloat, 1, pixelsCount);
	vDSP_vfixu8(dataAsFloat, 1, dataBlue, 4, pixelsCount);

	CGImageRef invertedImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* inverted = [UIImage imageWithCGImage:invertedImageRef];

	/// Cleanup
	CGImageRelease(invertedImageRef);
	free(dataAsFloat);
	CGContextRelease(bmContext);

	return inverted;
}

-(UIImage*)opacity:(float)value
{
	/// Create an ARGB bitmap context
	const size_t width = (size_t)self.size.width;
	const size_t height = (size_t)self.size.height;
	CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, width * kNyxNumberOfComponentsPerARBGPixel);
	if (!bmContext) 
		return nil;

	/// Set the alpha value and draw the image in the bitmap context
	CGContextSetAlpha(bmContext, value);
	CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, self.CGImage);

	/// Create an image object from the context
	CGImageRef transparentImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* transparent = [UIImage imageWithCGImage:transparentImageRef];

	/// Cleanup
	CGImageRelease(transparentImageRef);
	CGContextRelease(bmContext);

	return transparent;
}

-(UIImage*)sepia
{
	if ([CIImage class])
	{
		/// The sepia output from Core Image is nicer than manual method and 1.6x faster than vDSP
		CIImage* ciImage = [[CIImage alloc] initWithCGImage:self.CGImage];
		CIImage* output = [CIFilter filterWithName:@"CISepiaTone" keysAndValues:kCIInputImageKey, ciImage, @"inputIntensity", [NSNumber numberWithFloat:1.0f], nil].outputImage;
		CGImageRef cgImage = [NYXGetCIContext() createCGImage:output fromRect:[output extent]];
		UIImage* sepia = [UIImage imageWithCGImage:cgImage];
		CGImageRelease(cgImage);
		return sepia;
	}
	else
	{
		/* 1.6x faster than before */
		/// Create an ARGB bitmap context
		const size_t width = (size_t)self.size.width;
		const size_t height = (size_t)self.size.height;
		CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, width * kNyxNumberOfComponentsPerARBGPixel);
		if (!bmContext) 
			return nil;

		/// Draw the image in the bitmap context
		CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, self.CGImage);

		/// Grab the image raw data
		UInt8* data = (UInt8*)CGBitmapContextGetData(bmContext);
		if (!data)
		{
			CGContextRelease(bmContext);
			return nil;
		}

		const size_t pixelsCount = width * height;
		const size_t n = sizeof(float) * pixelsCount;
		float* reds = (float*)malloc(n);
		float* greens = (float*)malloc(n);
		float* blues = (float*)malloc(n);
		float* tmpRed = (float*)malloc(n);
		float* tmpGreen = (float*)malloc(n);
		float* tmpBlue = (float*)malloc(n);
		float* finalRed = (float*)malloc(n);
		float* finalGreen = (float*)malloc(n);
		float* finalBlue = (float*)malloc(n);
		float min = (float)kNyxMinPixelComponentValue, max = (float)kNyxMaxPixelComponentValue;

		/// Convert byte components to float
		vDSP_vfltu8(data + 1, 4, reds, 1, pixelsCount);
		vDSP_vfltu8(data + 2, 4, greens, 1, pixelsCount);
		vDSP_vfltu8(data + 3, 4, blues, 1, pixelsCount);

		/// Calculate red components
		vDSP_vsmul(reds, 1, &__sepiaFactorRedRed, tmpRed, 1, pixelsCount);
		vDSP_vsmul(greens, 1, &__sepiaFactorGreenRed, tmpGreen, 1, pixelsCount);
		vDSP_vsmul(blues, 1, &__sepiaFactorBlueRed, tmpBlue, 1, pixelsCount);
		vDSP_vadd(tmpRed, 1, tmpGreen, 1, finalRed, 1, pixelsCount);
		vDSP_vadd(finalRed, 1, tmpBlue, 1, finalRed, 1, pixelsCount);
		vDSP_vclip(finalRed, 1, &min, &max, finalRed, 1, pixelsCount);
		vDSP_vfixu8(finalRed, 1, data + 1, 4, pixelsCount);

		/// Calculate green components
		vDSP_vsmul(reds, 1, &__sepiaFactorRedGreen, tmpRed, 1, pixelsCount);
		vDSP_vsmul(greens, 1, &__sepiaFactorGreenGreen, tmpGreen, 1, pixelsCount);
		vDSP_vsmul(blues, 1, &__sepiaFactorBlueGreen, tmpBlue, 1, pixelsCount);
		vDSP_vadd(tmpRed, 1, tmpGreen, 1, finalGreen, 1, pixelsCount);
		vDSP_vadd(finalGreen, 1, tmpBlue, 1, finalGreen, 1, pixelsCount);
		vDSP_vclip(finalGreen, 1, &min, &max, finalGreen, 1, pixelsCount);
		vDSP_vfixu8(finalGreen, 1, data + 2, 4, pixelsCount);

		/// Calculate blue components
		vDSP_vsmul(reds, 1, &__sepiaFactorRedBlue, tmpRed, 1, pixelsCount);
		vDSP_vsmul(greens, 1, &__sepiaFactorGreenBlue, tmpGreen, 1, pixelsCount);
		vDSP_vsmul(blues, 1, &__sepiaFactorBlueBlue, tmpBlue, 1, pixelsCount);
		vDSP_vadd(tmpRed, 1, tmpGreen, 1, finalBlue, 1, pixelsCount);
		vDSP_vadd(finalBlue, 1, tmpBlue, 1, finalBlue, 1, pixelsCount);
		vDSP_vclip(finalBlue, 1, &min, &max, finalBlue, 1, pixelsCount);
		vDSP_vfixu8(finalBlue, 1, data + 3, 4, pixelsCount);

		/// Create an image object from the context
		CGImageRef sepiaImageRef = CGBitmapContextCreateImage(bmContext);
		UIImage* sepia = [UIImage imageWithCGImage:sepiaImageRef];

		/// Cleanup
		CGImageRelease(sepiaImageRef);
		free(reds), free(greens), free(blues), free(tmpRed), free(tmpGreen), free(tmpBlue), free(finalRed), free(finalGreen), free(finalBlue);
		CGContextRelease(bmContext);

		return sepia;
	}
}

-(UIImage*)sharpenWithBias:(NSInteger)bias
{
	/// Create an ARGB bitmap context
	const size_t width = (size_t)self.size.width;
	const size_t height = (size_t)self.size.height;
	const size_t bytesPerRow = width * kNyxNumberOfComponentsPerARBGPixel;
	CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, bytesPerRow);
	if (!bmContext) 
		return nil;

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, self.CGImage); 

	/// Grab the image raw data
	UInt8* data = (UInt8*)CGBitmapContextGetData(bmContext);
	if (!data)
	{
		CGContextRelease(bmContext);
		return nil;
	}

	const size_t n = sizeof(UInt8) * width * height * 4;
	void* outt = malloc(n);
	vImage_Buffer src = {data, height, width, bytesPerRow};
	vImage_Buffer dest = {outt, height, width, bytesPerRow};
	vImageConvolveWithBias_ARGB8888(&src, &dest, NULL, 0, 0, __s_sharpen_kernel_3x3, 3, 3, 1/*divisor*/, (int)bias, NULL, kvImageCopyInPlace);
	
	memcpy(data, outt, n);
	
	free(outt);

	CGImageRef sharpenedImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* sharpened = [UIImage imageWithCGImage:sharpenedImageRef];

	/// Cleanup
	CGImageRelease(sharpenedImageRef);
	CGContextRelease(bmContext);

	return sharpened;
}

-(UIImage*)unsharpenWithBias:(NSInteger)bias
{
	/// Create an ARGB bitmap context
	const size_t width = (size_t)self.size.width;
	const size_t height = (size_t)self.size.height;
	const size_t bytesPerRow = width * kNyxNumberOfComponentsPerARBGPixel;
	CGContextRef bmContext = NYXCreateARGBBitmapContext(width, height, bytesPerRow);
	if (!bmContext) 
		return nil;

	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, self.CGImage); 

	/// Grab the image raw data
	UInt8* data = (UInt8*)CGBitmapContextGetData(bmContext);
	if (!data)
	{
		CGContextRelease(bmContext);
		return nil;
	}

	const size_t n = sizeof(UInt8) * width * height * 4;
	void* outt = malloc(n);
	vImage_Buffer src = {data, height, width, bytesPerRow};
	vImage_Buffer dest = {outt, height, width, bytesPerRow};
	vImageConvolveWithBias_ARGB8888(&src, &dest, NULL, 0, 0, __s_unsharpen_kernel_3x3, 3, 3, 9/*divisor*/, (int)bias, NULL, kvImageCopyInPlace);
	
	memcpy(data, outt, n);
	
	free(outt);

	CGImageRef unsharpenedImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* unsharpened = [UIImage imageWithCGImage:unsharpenedImageRef];

	/// Cleanup
	CGImageRelease(unsharpenedImageRef);
	CGContextRelease(bmContext);

	return unsharpened;
}

@end
