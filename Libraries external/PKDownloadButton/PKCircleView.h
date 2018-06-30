//
//  PKCircleView.h
//  Download
//
//  Created by Pavel on 30/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#import <UIKit/UIKit.h>

IB_DESIGNABLE
@interface PKCircleView : UIView

@property (nonatomic, assign) IBInspectable CGFloat startAngleRadians;
@property (nonatomic, assign) IBInspectable CGFloat endAngleRadians;
@property (nonatomic, assign) IBInspectable CGFloat lineWidth;

@end
