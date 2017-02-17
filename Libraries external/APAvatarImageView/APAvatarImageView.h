//
//  APAvatarImageView.h
//  Avatar
//
//  Created by Ankur Patel on 10/19/13.
//  Copyright (c) 2013 Patel Labs LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface APAvatarImageView : UIImageView

@property (nonatomic, retain) UIColor *borderColor;
@property (nonatomic, assign) float borderWidth;
@property (nonatomic, assign) float cornerRadius;

- (id)initWithFrame:(CGRect)frame borderColor:(UIColor*)borderColor borderWidth:(float)borderWidth;
- (id)initWithImage:(UIImage *)image borderColor:(UIColor*)borderColor borderWidth:(float)borderWidth;
- (id)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage borderColor:(UIColor*)borderColor borderWidth:(float)borderWidth;

@end
