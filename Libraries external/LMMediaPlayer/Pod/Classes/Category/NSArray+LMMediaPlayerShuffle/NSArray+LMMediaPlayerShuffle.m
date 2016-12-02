//
//  NSArray+Shuffle.m
//  iPodMusicSample
//
//  Created by Akira Matsuda on 2014/01/22.
//  Copyright (c) 2014年 Akira Matsuda. All rights reserved.
//

#import "NSArray+LMMediaPlayerShuffle.h"

@implementation NSArray (LMMediaPlayerShuffle)

- (NSArray *)lm_shuffledArray
{
	NSMutableArray *results = [NSMutableArray arrayWithArray:self];
	NSUInteger i = [results count];

	while (--i) {
		[results exchangeObjectAtIndex:i withObjectAtIndex:(NSUInteger)arc4random_uniform(i + 1.0)];
	}

	return [NSArray arrayWithArray:results];
}

@end

@implementation NSMutableArray (LMMediaPlayerShuffle)

- (void)lm_shuffle
{
	NSUInteger i = [self count];
	while (--i) {
		[self exchangeObjectAtIndex:i withObjectAtIndex:(NSUInteger)arc4random_uniform(i + 1.0)];
	}
}

@end