//
//  PKPendingView.h
//  Download
//
//  Created by Pavel on 30/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PKCircleView.h"

IB_DESIGNABLE
@interface PKPendingView : UIControl

@property (nonatomic, weak, readonly) PKCircleView *circleView;

@property (nonatomic, assign) IBInspectable CGFloat radius;
@property (nonatomic, assign) IBInspectable CGFloat lineWidth;
@property (nonatomic, assign) IBInspectable CGFloat emptyLineRadians;
@property (nonatomic, assign) IBInspectable CGFloat spinTime;

- (void)startSpin;
- (void)stopSpin;

@end
