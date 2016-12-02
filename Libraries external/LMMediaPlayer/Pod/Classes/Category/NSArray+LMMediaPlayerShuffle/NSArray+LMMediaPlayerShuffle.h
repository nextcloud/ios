//
//  NSArray+Shuffle.h
//  iPodMusicSample
//
//  Created by Akira Matsuda on 2014/01/22.
//  Copyright (c) 2014年 Akira Matsuda. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (LMMediaPlayerShuffle)

- (NSArray *)lm_shuffledArray;

@end

@interface NSMutableArray (LMMediaPlayerShuffle)

- (void)lm_shuffle;

@end