//
//  LMMediaItem.m
//  iPodMusicSample
//
//  Created by Akira Matsuda on 2014/01/27.
//  Copyright (c) 2014年 Akira Matsuda. All rights reserved.
//

#import "LMMediaItem.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "LMMediaPlayerHelper.h"

@interface LMMediaItem () {
	id metaMedia_;
	NSString *title_;
	NSString *albumTitle_;
	NSString *artist_;
	UIImage *artworkImage_;
	NSURL *url_;
}

@end

@implementation LMMediaItem

NSString *LMMediaItemInfoTitleKey = @"LMMediaItemInfoTitleKey";
NSString *LMMediaItemInfoAlubumTitleKey = @"LMMediaItemInfoAlubumTitleKey";
NSString *LMMediaItemInfoArtistKey = @"LMMediaItemInfoArtistKey";
NSString *LMMediaItemInfoArtworkKey = @"LMMediaItemInfoArtworkKey";
NSString *LMMediaItemInfoURLKey = @"LMMediaItemInfoURLKey";
NSString *LMMediaItemInfoContentTypeKey = @"LMMediaItemInfoContentTypeKey";

@synthesize title = title_;
@synthesize albumTitle = albumTitle_;
@synthesize artist = artist_;
@synthesize assetURL = url_;

- (void)dealloc
{
	LM_RELEASE(title_);
	LM_RELEASE(albumTitle_);
	LM_RELEASE(artist_);
	LM_RELEASE(artworkImage_);
	LM_RELEASE(url_);
	LM_DEALLOC(super);
}

- (instancetype)initWithMetaMedia:(id)media contentType:(LMMediaItemContentType)type
{
	self = [super init];
	if (self) {
		metaMedia_ = media;
		_contentType = type;
	}

	return self;
}

- (instancetype)initWithInfo:(NSDictionary *)info
{
	self = [super init];
	if (self) {
		title_ = ([info[LMMediaItemInfoTitleKey] isKindOfClass:[NSString class]] ? [info[LMMediaItemInfoTitleKey] copy] : nil);
		albumTitle_ = ([info[LMMediaItemInfoAlubumTitleKey] isKindOfClass:[NSString class]] ? [info[LMMediaItemInfoAlubumTitleKey] copy] : nil);
		artist_ = ([info[LMMediaItemInfoArtistKey] isKindOfClass:[NSString class]] ? [info[LMMediaItemInfoArtistKey] copy] : nil);
		artworkImage_ = ([info[LMMediaItemInfoArtworkKey] isKindOfClass:[UIImage class]] ? [info[LMMediaItemInfoArtworkKey] copy] : nil);
		url_ = ([info[LMMediaItemInfoURLKey] isKindOfClass:[NSURL class]] ? [info[LMMediaItemInfoURLKey] copy] : nil);
		_contentType = (LMMediaItemContentType)([info[LMMediaItemInfoContentTypeKey] isKindOfClass:[NSNumber class]] ? [info[LMMediaItemInfoContentTypeKey] integerValue] : -1);
	}

	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super init];
	if (self) {
		title_ = [coder decodeObjectForKey:LMMediaItemInfoTitleKey];
		albumTitle_ = [coder decodeObjectForKey:LMMediaItemInfoAlubumTitleKey];
		artist_ = [coder decodeObjectForKey:LMMediaItemInfoArtistKey];
		artworkImage_ = [coder decodeObjectForKey:LMMediaItemInfoArtworkKey];
		url_ = [coder decodeObjectForKey:LMMediaItemInfoURLKey];
		_contentType = (LMMediaItemContentType)[[coder decodeObjectForKey:LMMediaItemInfoContentTypeKey] integerValue];
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:title_ forKey:LMMediaItemInfoTitleKey];
	[coder encodeObject:albumTitle_ forKey:LMMediaItemInfoAlubumTitleKey];
	[coder encodeObject:artist_ forKey:LMMediaItemInfoArtistKey];
	[coder encodeObject:artworkImage_ forKey:LMMediaItemInfoArtworkKey];
	[coder encodeObject:url_ forKey:LMMediaItemInfoURLKey];
	[coder encodeObject:[NSNumber numberWithInteger:_contentType] forKey:LMMediaItemInfoContentTypeKey];
}

- (id)copyWithZone:(NSZone *)zone
{
	NSMutableDictionary *newInfo = [NSMutableDictionary new];
	if (self.title) {
		NSString *newString = [self.title copy];
		LM_AUTORELEASE(newString);
		newInfo[LMMediaItemInfoTitleKey] = newString ?: [NSNull null];
	}
	if (self.albumTitle) {
		NSString *newString = [self.albumTitle copy];
		LM_AUTORELEASE(newString);
		newInfo[LMMediaItemInfoAlubumTitleKey] = newString ?: [NSNull null];
	}
	if (self.artist) {
		NSString *newString = [self.artist copy];
		LM_AUTORELEASE(newString);
		newInfo[LMMediaItemInfoArtistKey] = newString ?: [NSNull null];
	}
	if (artworkImage_) {
		UIImage *newImage = [artworkImage_ copy];
		LM_AUTORELEASE(newImage);
		newInfo[LMMediaItemInfoArtworkKey] = newImage ?: [NSNull null];
	}
	if (self.assetURL) {
		NSURL *newURL = [self.assetURL copy];
		LM_AUTORELEASE(newURL);
		newInfo[LMMediaItemInfoURLKey] = newURL ?: [NSNull null];
	}
	newInfo[LMMediaItemInfoContentTypeKey] = [NSNumber numberWithInteger:_contentType];

	LMMediaItem *newObject = [[[self class] allocWithZone:zone] initWithInfo:newInfo];
	LM_RELEASE(newInfo);

	return newObject;
}

- (id)valueWithProperty:(NSString *)property cache:(id)cache
{
	id returnValue = nil;
	if ([metaMedia_ isKindOfClass:[MPMediaItem class]]) {
		returnValue = cache = [metaMedia_ valueForProperty:property];
	}

	return returnValue;
}

- (NSString *)title
{
	return title_ ?: [self valueWithProperty:MPMediaItemPropertyTitle cache:title_];
}

- (NSString *)albumTitle
{
	return albumTitle_ ?: [self valueWithProperty:MPMediaItemPropertyAlbumTitle cache:albumTitle_];
}

- (NSString *)artist
{
	return artist_ ?: [self valueWithProperty:MPMediaItemPropertyArtist cache:artist_];
}

- (UIImage *)artworkImageWithSize:(CGSize)size
{
	UIImage * (^f)(id) = ^UIImage *(id metaMedia)
	{
		UIImage *image = nil;
		if ([metaMedia isKindOfClass:[MPMediaItem class]]) {
			artworkImage_ = image = [[metaMedia_ valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:size];
		}

		return image;
	};

	return artworkImage_ ?: f(metaMedia_);
}

- (void)setArtworkImage:(UIImage *)image
{
	artworkImage_ = [image copy];
}

- (NSURL *)assetURL
{
	return url_ ?: [self valueWithProperty:MPMediaItemPropertyAssetURL cache:url_];
}

- (id)metaMedia
{
	return metaMedia_;
}

- (BOOL)isVideo
{
	return _contentType == LMMediaItemContentTypeVideo;
}

- (NSString *)description
{
	return [@{ @"title" : title_ ?: @"nil",
		@"album" : albumTitle_ ?: @"nil",
		@"artist" : artist_ ?: @"nil",
		@"url" : url_ ?: @"nil",
		@"artwork" : artworkImage_ ?: @"nil",
		@"content type" : _contentType == LMMediaItemContentTypeAudio ? @"LMMediaItemContentTypeAudio" : @"LMMediaItemContentTypeVideo",
		@"meta media" : metaMedia_ ?: @"nil" } description];
}

@end
