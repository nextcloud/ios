//
//  CALayer+PKDownloadButtonAnimations.h
//  Download
//
//  Created by Pavel on 31/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface CALayer (PKDownloadButtonAnimations)

- (void)addRotationAnimationWithKey:(NSString *)animationKey
               fullRotationDuration:(NSTimeInterval)fullRotationDuration;
- (void)removeRotationAnimationWithKey:(NSString *)animationKey;
- (void)removeRotationAnimationWithKey:(NSString *)animationKey
                  fullRotationDuration:(NSTimeInterval)fullRotationDuration;

@end
