//
//  PKCircleView.m
//  Download
//
//  Created by Pavel on 30/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#import "PKCircleView.h"

static const CGFloat kDefaultLineWidth = 1.f;

@interface PKCircleView ()

- (void)drawCircleRadius:(CGFloat)radius
                    rect:(CGRect)rect
              startAngle:(CGFloat)startAngle
                endAngle:(CGFloat)endAngel
               lineWidth:(CGFloat)lineWidth;

@end

static PKCircleView *CommonInit(PKCircleView *self) {
    if (self != nil) {
        self.backgroundColor = [UIColor clearColor];
        self.startAngleRadians = M_PI * 1.5;
        self.endAngleRadians = self.startAngleRadians + (M_PI * 2);
        self.lineWidth = kDefaultLineWidth;
    }
    return self;
}

@implementation PKCircleView

#pragma mark - initialization

- (id)initWithCoder:(NSCoder *)decoder {
    return CommonInit([super initWithCoder:decoder]);
}

- (instancetype)initWithFrame:(CGRect)frame {
    return CommonInit([super initWithFrame:frame]);
}

#pragma mark - properties

- (void)setLineWidth:(CGFloat)lineWidth {
    _lineWidth = lineWidth;
    [self setNeedsDisplay];
}

- (void)setStartAngleRadians:(CGFloat)startAngleRadians {
    _startAngleRadians = startAngleRadians;
    [self setNeedsDisplay];
}

- (void)setEndAngleRadians:(CGFloat)endAngleRadians {
    _endAngleRadians = endAngleRadians;
    [self setNeedsDisplay];
}

#pragma mark - UIView

- (void)drawRect:(CGRect)rect {
    [self drawCircleRadius:MIN(rect.size.width / 2, rect.size.height / 2) - self.lineWidth / 2.f
                      rect:rect
                startAngle:self.startAngleRadians
                  endAngle:self.endAngleRadians
                 lineWidth:self.lineWidth];
}

#pragma mark - private methods

- (void)drawCircleRadius:(CGFloat)radius
                    rect:(CGRect)rect
              startAngle:(CGFloat)startAngle
                endAngle:(CGFloat)endAngel
               lineWidth:(CGFloat)lineWidth {
    UIBezierPath* bezierPath = [UIBezierPath bezierPath];
    [self.tintColor setStroke];
    [bezierPath addArcWithCenter:CGPointMake(rect.size.width / 2, rect.size.height / 2)
                          radius:radius
                      startAngle:startAngle
                        endAngle:endAngel
                       clockwise:YES];
    
    bezierPath.lineWidth = lineWidth;
    [bezierPath stroke];
}

@end
