//
//  LMMediaPlayerHelper.h
//  LMMediaPlayer
//
//  Created by Akira Matsuda on 8/31/14.
//  Copyright (c) 2014 Akira Matsuda. All rights reserved.
//

#import <Foundation/Foundation.h>

#if !__has_feature(objc_arc)
#define LM_AUTORELEASE(v) [v autorelease]
#define LM_RETAIN(v) [v retain]
#define LM_DEALLOC(v) [v dealloc]
#define LM_RELEASE(v) [v release]
#define LM_RELEASE_NIL(v) \
	[v release];      \
	v = nil;
#else
#define LM_AUTORELEASE(v)
#define LM_RETAIN(v)
#define LM_DEALLOC(v)
#define LM_RELEASE(v)
#define LM_RELEASE_NIL(v)
#endif

@interface LMMediaPlayerHelper : NSObject

@end
