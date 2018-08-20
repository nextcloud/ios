//
//  PKCircleProgressView.h
//  PKDownloadButton
//
//  Created by Pavel on 28/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#import <UIKit/UIKit.h>

IB_DESIGNABLE
@interface PKCircleProgressView : UIView

@property (nonatomic, assign) IBInspectable CGFloat progress; /// 0.f - 1.0f
@property (nonatomic, assign) IBInspectable CGFloat filledLineWidth; /// 0.f +
@property (nonatomic, assign) IBInspectable CGFloat emptyLineWidth; /// 0.f +
@property (nonatomic, assign) IBInspectable CGFloat radius; /// 0.f +
@property (nonatomic, assign) IBInspectable BOOL filledLineStyleOuter;

@end
