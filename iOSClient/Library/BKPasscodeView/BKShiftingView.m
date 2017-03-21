//
//  BKShiftingView.m
//  BKPasscodeViewDemo
//
//  Created by Byungkook Jang on 2014. 10. 11..
//  Copyright (c) 2014년 Byungkook Jang. All rights reserved.
//

#import "BKShiftingView.h"

@implementation BKShiftingView

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.currentView.frame = self.bounds;
}

- (void)setCurrentView:(UIView *)currentView
{
    if (_currentView == currentView) {
        return;
    }
    
    [_currentView removeFromSuperview];
    
    _currentView = currentView;
    
    if (currentView) {
        [self addSubview:currentView];
    }
    
    [self setNeedsLayout];
}

- (void)showView:(UIView *)view withDirection:(BKShiftingDirection)direction
{
    UIView *oldView = self.currentView;
    oldView.userInteractionEnabled = NO;

    CGRect nextFrame = self.bounds;
    
    switch (direction) {
        case BKShiftingDirectionForward:
            nextFrame.origin.x = CGRectGetWidth(self.bounds);
            break;
        case BKShiftingDirectionBackward:
            nextFrame.origin.x = -CGRectGetWidth(self.bounds);
            break;
    }
    
    view.frame = nextFrame;
    
    [self addSubview:view];
    
    // start animation
    [UIView animateWithDuration:0.3f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        
        switch (direction) {
            case BKShiftingDirectionForward:
                oldView.frame = CGRectOffset(oldView.frame, -CGRectGetWidth(self.bounds), 0);
                view.frame = CGRectOffset(view.frame, -CGRectGetWidth(self.bounds), 0);
                break;
            case BKShiftingDirectionBackward:
                oldView.frame = CGRectOffset(oldView.frame, CGRectGetWidth(self.bounds), 0);
                view.frame = CGRectOffset(view.frame, CGRectGetWidth(self.bounds), 0);
                break;
        }
        
    } completion:^(BOOL finished) {
        
        [oldView removeFromSuperview];
        
    }];
    
    _currentView = view;
}

@end
