//
//  CALayer+PKDownloadButtonAnimations.m
//  Download
//
//  Created by Pavel on 31/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#import "CALayer+PKDownloadButtonAnimations.h"

static NSString *kRorationEndKey = @"PKLayerRorationEndKey";

@implementation CALayer (PKDownloadButtonAnimations)

- (void)addRotationAnimationWithKey:(NSString *)animationKey fullRotationDuration:(NSTimeInterval)fullRotationDuration {
    NSNumber *fromValue = [self.presentationLayer valueForKeyPath:@"transform.rotation"];
    [self removeAnimationForKey:kRorationEndKey];
    
    CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    rotationAnimation.fromValue = fromValue;
    rotationAnimation.toValue = @([rotationAnimation.fromValue floatValue] + (2. * M_PI));
    rotationAnimation.duration = fullRotationDuration;
    rotationAnimation.repeatCount = HUGE_VALF;
    rotationAnimation.removedOnCompletion = NO;
    
    [self addAnimation:rotationAnimation forKey:animationKey];
}

- (void)removeRotationAnimationWithKey:(NSString *)animationKey {
    [self removeRotationAnimationWithKey:animationKey fullRotationDuration:0.0];
}

- (void)removeRotationAnimationWithKey:(NSString *)animationKey fullRotationDuration:(NSTimeInterval)fullRotationDuration {
    NSNumber *fromValue = [self.presentationLayer valueForKeyPath:@"transform.rotation"];
    NSNumber *toValue = @((fromValue.doubleValue < 0.0) ? 0.0 : 2.0 * M_PI);
    
    [self removeAnimationForKey:animationKey];
    
    const NSTimeInterval animationDuration = ABS(toValue.doubleValue - fromValue.doubleValue) * (fullRotationDuration / (2.0 * M_PI));
    
    if (fromValue.doubleValue != 0.0 && ![fromValue isEqualToNumber:toValue] && animationDuration > 0.0) {
        [CATransaction begin];
        CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
        rotationAnimation.fromValue = fromValue;
        rotationAnimation.toValue = toValue;
        rotationAnimation.duration = animationDuration;
        
        [CATransaction setCompletionBlock:^{
            [self removeAnimationForKey:kRorationEndKey];
        }];
        
        [self addAnimation:rotationAnimation forKey:kRorationEndKey];
        [CATransaction commit];
    }
    else {
        [self removeAnimationForKey:kRorationEndKey];
    }
}

@end
