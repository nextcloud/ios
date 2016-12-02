//
//  UIImage+Saving.h
//  NYXImagesKit
//
//  Created by @Nyx0uf on 05/05/11.
//  Copyright 2012 Nyx0uf. All rights reserved.
//  www.cocoaintheshell.com
//


#import "NYXImagesHelper.h"


typedef enum
{
	NYXImageTypePNG,
	NYXImageTypeJPEG,
	NYXImageTypeGIF,
	NYXImageTypeBMP,
	NYXImageTypeTIFF
} NYXImageType;


@interface UIImage (NYX_Saving)

-(BOOL)saveToURL:(NSURL*)url uti:(CFStringRef)uti backgroundFillColor:(UIColor*)fillColor;

-(BOOL)saveToURL:(NSURL*)url type:(NYXImageType)type backgroundFillColor:(UIColor*)fillColor;

-(BOOL)saveToURL:(NSURL*)url;

-(BOOL)saveToPath:(NSString*)path uti:(CFStringRef)uti backgroundFillColor:(UIColor*)fillColor;

-(BOOL)saveToPath:(NSString*)path type:(NYXImageType)type backgroundFillColor:(UIColor*)fillColor;

-(BOOL)saveToPath:(NSString*)path;

-(BOOL)saveToPhotosAlbum;

+(NSString*)extensionForUTI:(CFStringRef)uti;

@end
