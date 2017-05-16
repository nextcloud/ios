//
//  CCMenuAccount.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 07/04/16.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#import "CCMenuAccount.h"

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

@interface CCMenuOverlay : UIView
@end

@implementation CCMenuOverlay

- (id)initWithFrame:(CGRect)frame maskSetting:(Boolean)mask
{
    self = [super initWithFrame:frame];
    
    if (self) {
        
        if (mask) {
            self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.17];
        } else {
            self.backgroundColor = [UIColor clearColor];
        }
        
        UITapGestureRecognizer *gestureRecognizer;
        gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                    action:@selector(singleTap:)];
        
        [self addGestureRecognizer:gestureRecognizer];
    }
    return self;
}

// thank horaceho https://github.com/horaceho
// for his solution described in https://github.com/kolyvan/kxmenu/issues/9

- (void)singleTap:(UITapGestureRecognizer *)recognizer
{
    for (UIView *v in self.subviews) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        if ([v isKindOfClass:[CCMenuView class]] && [v respondsToSelector:@selector(dismissMenu:)]) {
            [v performSelector:@selector(dismissMenu:) withObject:@(YES)];
        }
#pragma clang diagnostic pop
    }
}

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

@implementation CCMenuItem

+ (instancetype) menuItem:(NSString *)title argument:(NSString*)argument image:(UIImage *)image target:(id)target action:(SEL)action
{
    return [[CCMenuItem alloc] init:title argument:argument image:image target:target action:action];
}

- (id)init:(NSString *)title argument:(NSString*)argument image:(UIImage *)image target:(id)target action:(SEL)action
{
    NSParameterAssert(title.length || image);
    
    self = [super init];
    if (self) {
        
        _title = title;
        _argument = argument;
        _image = image;
        _target = target;
        _action = action;
    }
    return self;
}

- (BOOL)enabled
{
    return _target != nil && _action != NULL;
}

- (void)performAction
{
    __strong id target = self.target;
    
    if (target && [target respondsToSelector:_action]) {
        
        [target performSelectorOnMainThread:_action withObject:self waitUntilDone:YES];
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ #%p %@>", [self class], self, _title];
}

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

typedef enum {
    
    CCMenuViewArrowDirectionNone,
    CCMenuViewArrowDirectionUp,
    CCMenuViewArrowDirectionDown,
    CCMenuViewArrowDirectionLeft,
    CCMenuViewArrowDirectionRight,
    
} CCMenuViewArrowDirection;

@implementation CCMenuView {
    
    CCMenuViewArrowDirection    _arrowDirection;
    CGFloat                     _arrowPosition;
    UIView                      *_contentView;
    NSArray                     *_menuItems;
}

- (id)init
{
    self = [super initWithFrame:CGRectZero];
    if(self) {
        
        self.backgroundColor = [UIColor clearColor];
        
        self.opaque = YES;
        self.alpha = 0;
    }
    
    return self;
}

- (void)setupFrameInView:(UIView *)view fromRect:(CGRect)fromRect
{
    const CGSize contentSize = _contentView.frame.size;
    const CGFloat outerWidth = view.bounds.size.width;
    const CGFloat rectXM = fromRect.origin.x + fromRect.size.width * 0.5f;
    const CGFloat widthHalf = contentSize.width * 0.5f;
    const CGFloat kMargin = 5.f;
    const CGFloat rectY = fromRect.origin.y;
    
    if (self.CCMenuViewOptions.shadowOfMenu) {
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowOffset = CGSizeMake(2, 2);
        self.layer.shadowRadius = 2;
        
        self.layer.shadowColor = [[UIColor blackColor] CGColor];
    }
    
    _arrowDirection = CCMenuViewArrowDirectionUp;
    
    CGPoint point = (CGPoint){
        rectXM - widthHalf,
        rectY - 4
    };
    
    if (point.x < kMargin)
        point.x = kMargin;
    
    if ((point.x + contentSize.width + kMargin) > outerWidth)
        point.x = outerWidth - contentSize.width - kMargin;
    
    _arrowPosition = rectXM - point.x;
    _contentView.frame = (CGRect){CGPointZero, contentSize};
    
    self.frame = (CGRect) {
        
        point,
        contentSize.width,
        contentSize.height - self.CCMenuViewOptions.arrowSize
    };
}

- (void)showMenuInView:(UIView *)view fromRect:(CGRect)rect menuItems:(NSArray *)menuItems withOptions:(OptionalConfiguration)options
{
    
    self.CCMenuViewOptions = options;
    
    _menuItems = menuItems;
    
    _contentView = [self mkContentView];
    [self addSubview:_contentView];
    
    [self setupFrameInView:view fromRect:rect];
    
    CCMenuOverlay *overlay = [[CCMenuOverlay alloc] initWithFrame:view.bounds maskSetting:self.CCMenuViewOptions.maskToBackground];

    [overlay addSubview:self];
    [view addSubview:overlay];
    
    _contentView.hidden = YES;
    const CGRect toFrame = self.frame;
    self.frame = (CGRect){self.arrowPoint, 1, 1};
    
    [UIView animateWithDuration:0.2
                     animations:^(void) {
                         
                         self.alpha = 1.0f;
                         self.frame = toFrame;
                         
                     } completion:^(BOOL completed) {
                         _contentView.hidden = NO;
                     }];
    
}

- (void)dismissMenu:(BOOL) noAnimated
{
    if (self.superview) {
        
        if (!noAnimated) {
            
            const CGRect toFrame = (CGRect){self.arrowPoint, 1, 1};
            _contentView.hidden = YES;
            
            [UIView animateWithDuration:0.1
                             animations:^(void) {
                                 
                                 self.alpha = 0;
                                 self.frame = toFrame;
                                 
                             } completion:^(BOOL finished) {
                                 
                                 if ([self.superview isKindOfClass:[CCMenuOverlay class]])
                                     [self.superview removeFromSuperview];
                                 [self removeFromSuperview];
                             }];
            
        } else {
            
            if ([self.superview isKindOfClass:[CCMenuOverlay class]])
                [self.superview removeFromSuperview];
            [self removeFromSuperview];
        }
    }
}

- (void)performAction:(id)sender
{
    [self dismissMenu:YES];
    
    UIButton *button = (UIButton *)sender;
    CCMenuItem *menuItem = _menuItems[button.tag];
    [menuItem performAction];
}

- (UIView *)mkContentView
{
    for (UIView *v in self.subviews) {
        [v removeFromSuperview];
    }
    
    if (!_menuItems.count)
        return nil;
    
    const CGFloat kMinMenuItemHeight = 32.f;
    const CGFloat kMinMenuItemWidth = 32.f;
    const CGFloat kMarginX = self.CCMenuViewOptions.marginXSpacing;
    const CGFloat kMarginY = self.CCMenuViewOptions.marginYSpacing;
    
    UIFont *titleFont = [CCMenuAccount titleFont];
    if (!titleFont) titleFont = [UIFont boldSystemFontOfSize:16];
    
    CGFloat maxImageWidth = 0;
    CGFloat maxItemHeight = 0;
    CGFloat maxItemWidth = 0;
    
    for (CCMenuItem *menuItem in _menuItems) {
        
        const CGSize imageSize = menuItem.image.size;
        if (imageSize.width > maxImageWidth)
            maxImageWidth = imageSize.width;
    }
    
    if (maxImageWidth) {
        maxImageWidth += kMarginX;
    }
    
    for (CCMenuItem *menuItem in _menuItems) {
        
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        const CGSize titleSize = [menuItem.title sizeWithAttributes:@{NSFontAttributeName: titleFont}];
#else
        const CGSize titleSize = [menuItem.title sizeWithFont:titleFont];
#endif       
        const CGSize imageSize = menuItem.image.size;
        
        const CGFloat itemHeight = MAX(titleSize.height, imageSize.height) + kMarginY * 2;
        
        const CGFloat itemWidth = ((!menuItem.enabled && !menuItem.image) ? titleSize.width : maxImageWidth + titleSize.width) + kMarginX * 2 + self.CCMenuViewOptions.intervalSpacing;
        
        if (itemHeight > maxItemHeight)
            maxItemHeight = itemHeight;
        
        if (itemWidth > maxItemWidth)
            maxItemWidth = itemWidth;
    }
    
    maxItemWidth  = MAX(maxItemWidth, kMinMenuItemWidth);
    maxItemHeight = MAX(maxItemHeight, kMinMenuItemHeight);
    
    const CGFloat titleX = maxImageWidth + self.CCMenuViewOptions.intervalSpacing;
    
    const CGFloat titleWidth = maxItemWidth - titleX - kMarginX *2;
    
    UIImage *selectedImage = [CCMenuView selectedImage:(CGSize){maxItemWidth, maxItemHeight + 2}];
    int insets = 0;
    
    if (self.CCMenuViewOptions.seperatorLineHasInsets) {
        insets = 4;
    }
    
    UIImage *gradientLine = [CCMenuView gradientLine: (CGSize){maxItemWidth- kMarginX * insets, 0.4}];
    
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectZero];
    contentView.autoresizingMask = UIViewAutoresizingNone;
    
    contentView.backgroundColor = [UIColor clearColor];
    
    contentView.opaque = NO;
    
    CGFloat itemY = kMarginY * 2;
    
    NSUInteger itemNum = 0;
    
    for (CCMenuItem *menuItem in _menuItems) {
        
        const CGRect itemFrame = (CGRect){0, itemY-kMarginY * 2 + self.CCMenuViewOptions.menuCornerRadius, maxItemWidth, maxItemHeight};
        
        UIView *itemView = [[UIView alloc] initWithFrame:itemFrame];
        itemView.autoresizingMask = UIViewAutoresizingNone;
        
        itemView.opaque = NO;
        
        [contentView addSubview:itemView];
        
        if (menuItem.enabled) {
            
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.tag = itemNum;
            button.frame = itemView.bounds;
            button.enabled = menuItem.enabled;
            
            button.backgroundColor = [UIColor clearColor];
            
            button.opaque = NO;
            button.autoresizingMask = UIViewAutoresizingNone;
            
            [button addTarget:self
                       action:@selector(performAction:)
             forControlEvents:UIControlEventTouchUpInside];
            
            [button setBackgroundImage:selectedImage forState:UIControlStateHighlighted];
            
            [itemView addSubview:button];
        }
        
        if (menuItem.title.length) {
            
            CGRect titleFrame;
            
            if (!menuItem.enabled && !menuItem.image) {
                
                titleFrame = (CGRect){
                    kMarginX * 2,
                    kMarginY,
                    maxItemWidth - kMarginX * 4,
                    maxItemHeight - kMarginY * 2
                };
                
            } else {
                
                titleFrame = (CGRect){
                    titleX,
                    kMarginY,
                    titleWidth,
                    maxItemHeight - kMarginY * 2
                };
            }
            
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:titleFrame];
            titleLabel.text = menuItem.title;
            titleLabel.font = titleFont;
            titleLabel.textAlignment = menuItem.alignment;
            
            //titleLabel.textColor = menuItem.foreColor ? menuItem.foreColor : [UIColor blackColor];
            titleLabel.textColor = [UIColor colorWithRed:self.CCMenuViewOptions.textColor.R green:self.CCMenuViewOptions.textColor.G blue:self.CCMenuViewOptions.textColor.B alpha:1];
            
            titleLabel.backgroundColor = [UIColor clearColor];
            
            titleLabel.autoresizingMask = UIViewAutoresizingNone;
            
            [itemView addSubview:titleLabel];
        }
        
        if (menuItem.image) {
            
            const CGRect imageFrame = {kMarginX * 2, kMarginY, maxImageWidth, maxItemHeight - kMarginY * 2};
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageFrame];
            imageView.image = menuItem.image;
            imageView.clipsToBounds = YES;
            imageView.contentMode = UIViewContentModeCenter;
            imageView.autoresizingMask = UIViewAutoresizingNone;
            [itemView addSubview:imageView];
        }
        
        if (itemNum < _menuItems.count - 1) {
            
            UIImageView *gradientView = [[UIImageView alloc] initWithImage:gradientLine];
            
            if (self.CCMenuViewOptions.seperatorLineHasInsets) {
                gradientView.frame = (CGRect){kMarginX * 2, maxItemHeight + 1, gradientLine.size};
            } else {
                gradientView.frame = (CGRect){0, maxItemHeight + 1 , gradientLine.size};
            }
            
            gradientView.contentMode = UIViewContentModeLeft;
            
            if (self.CCMenuViewOptions.hasSeperatorLine) {
                [itemView addSubview:gradientView];
                itemY += 2;
            }
            
            itemY += maxItemHeight;
        }
        
        ++itemNum;
    }
    
    itemY += self.CCMenuViewOptions.menuCornerRadius;
    
    contentView.frame = (CGRect){0, 0, maxItemWidth, itemY + kMarginY * 2 + 5.5 + self.CCMenuViewOptions.menuCornerRadius};
    
    return contentView;
}

- (CGPoint)arrowPoint
{
    CGPoint point;
    
    if (_arrowDirection == CCMenuViewArrowDirectionUp) {
        
        point = (CGPoint){ CGRectGetMinX(self.frame) + _arrowPosition, CGRectGetMinY(self.frame) };
        
    } else if (_arrowDirection == CCMenuViewArrowDirectionDown) {
        
        point = (CGPoint){ CGRectGetMinX(self.frame) + _arrowPosition, CGRectGetMaxY(self.frame) };
        
    } else if (_arrowDirection == CCMenuViewArrowDirectionLeft) {
        
        point = (CGPoint){ CGRectGetMinX(self.frame), CGRectGetMinY(self.frame) + _arrowPosition  };
        
    } else if (_arrowDirection == CCMenuViewArrowDirectionRight) {
        
        point = (CGPoint){ CGRectGetMaxX(self.frame), CGRectGetMinY(self.frame) + _arrowPosition  };
        
    } else {
        
        point = self.center;
    }
    
    return point;
}

+ (UIImage *)selectedImage:(CGSize)size
{

    const CGFloat locations[] = {0,1};

    const CGFloat components[] = {
        0.890,0.890,0.890,1,
        0.890,0.890,0.890,1
    };
    
    return [self gradientImageWithSize:size locations:locations components:components count:2];
}

+ (UIImage *)gradientLine:(CGSize)size
{
    const CGFloat locations[5] = {0,0.2,0.5,0.8,1};
    
    const CGFloat R = 0.890f, G = 0.890f, B = 0.890f;
    
    const CGFloat components[20] = {
        R,G,B,1,
        R,G,B,1,
        R,G,B,1,
        R,G,B,1,
        R,G,B,1
    };
    
    return [self gradientImageWithSize:size locations:locations components:components count:5];
}

+ (UIImage *)gradientImageWithSize:(CGSize)size locations:(const CGFloat [])locations components:(const CGFloat [])components count:(NSUInteger)count
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef colorGradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawLinearGradient(context, colorGradient, (CGPoint){0, 0}, (CGPoint){size.width, 0}, 0);
    CGGradientRelease(colorGradient);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)drawRect:(CGRect)rect
{
    [self drawBackground:self.bounds inContext:UIGraphicsGetCurrentContext()];
}

- (void)drawBackground:(CGRect)frame inContext:(CGContextRef)context
{
    CGFloat R0 = self.CCMenuViewOptions.menuBackgroundColor.R, G0 = self.CCMenuViewOptions.menuBackgroundColor.G, B0 = self.CCMenuViewOptions.menuBackgroundColor.B;
    
    CGFloat R1 = R0, G1 = G0, B1 = B0;
    
    UIColor *tintColor = [CCMenuAccount tintColor];
    if (tintColor) {
        
        CGFloat a;
        [tintColor getRed:&R0 green:&G0 blue:&B0 alpha:&a];
    }
    
    CGFloat X0 = frame.origin.x;
    CGFloat X1 = frame.origin.x + frame.size.width;
    CGFloat Y0 = frame.origin.y;
    CGFloat Y1 = frame.origin.y + frame.size.height;
    
    // render arrow
    
    UIBezierPath *arrowPath = [UIBezierPath bezierPath];
    
    // fix the issue with gap of arrow's base if on the edge
    const CGFloat kEmbedFix = 3.f;
    
    if (_arrowDirection == CCMenuViewArrowDirectionUp) {
        
        const CGFloat arrowXM = _arrowPosition;
        const CGFloat arrowX0 = arrowXM - self.CCMenuViewOptions.arrowSize;
        const CGFloat arrowX1 = arrowXM + self.CCMenuViewOptions.arrowSize;
        const CGFloat arrowY0 = Y0;
        const CGFloat arrowY1 = Y0 + self.CCMenuViewOptions.arrowSize + kEmbedFix;
        
        [arrowPath moveToPoint:    (CGPoint){arrowXM, arrowY0}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY1}];
        [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowY1}];
        [arrowPath addLineToPoint: (CGPoint){arrowXM, arrowY0}];
        
        
        [[UIColor colorWithRed:R0 green:G0 blue:B0 alpha:1] set];
        
        Y0 += self.CCMenuViewOptions.arrowSize;
        
    } else if (_arrowDirection == CCMenuViewArrowDirectionDown) {
        
        const CGFloat arrowXM = _arrowPosition;
        const CGFloat arrowX0 = arrowXM - self.CCMenuViewOptions.arrowSize;
        const CGFloat arrowX1 = arrowXM + self.CCMenuViewOptions.arrowSize;
        const CGFloat arrowY0 = Y1 - self.CCMenuViewOptions.arrowSize - kEmbedFix;
        const CGFloat arrowY1 = Y1;
        
        [arrowPath moveToPoint:    (CGPoint){arrowXM, arrowY1}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY0}];
        [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowY0}];
        [arrowPath addLineToPoint: (CGPoint){arrowXM, arrowY1}];
        
        [[UIColor colorWithRed:R1 green:G1 blue:B1 alpha:1] set];
        
        Y1 -= self.CCMenuViewOptions.arrowSize;
        
    } else if (_arrowDirection == CCMenuViewArrowDirectionLeft) {
        
        const CGFloat arrowYM = _arrowPosition;
        const CGFloat arrowX0 = X0;
        const CGFloat arrowX1 = X0 + self.CCMenuViewOptions.arrowSize + kEmbedFix;
        const CGFloat arrowY0 = arrowYM - self.CCMenuViewOptions.arrowSize;;
        const CGFloat arrowY1 = arrowYM + self.CCMenuViewOptions.arrowSize;
        
        [arrowPath moveToPoint:    (CGPoint){arrowX0, arrowYM}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY0}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY1}];
        [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowYM}];
        
        [[UIColor colorWithRed:R0 green:G0 blue:B0 alpha:1] set];
        
        X0 += self.CCMenuViewOptions.arrowSize;
        
    } else if (_arrowDirection == CCMenuViewArrowDirectionRight) {
        
        const CGFloat arrowYM = _arrowPosition;
        const CGFloat arrowX0 = X1;
        const CGFloat arrowX1 = X1 - self.CCMenuViewOptions.arrowSize - kEmbedFix;
        const CGFloat arrowY0 = arrowYM - self.CCMenuViewOptions.arrowSize;;
        const CGFloat arrowY1 = arrowYM + self.CCMenuViewOptions.arrowSize;
        
        [arrowPath moveToPoint:    (CGPoint){arrowX0, arrowYM}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY0}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY1}];
        [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowYM}];
        
        [[UIColor colorWithRed:R1 green:G1 blue:B1 alpha:1] set];
        
        X1 -= self.CCMenuViewOptions.arrowSize;
    }
    
    [arrowPath fill];
    
    // render body
    
    const CGRect bodyFrame = {X0, Y0, X1 - X0, Y1 - Y0};
    
    UIBezierPath *borderPath = [UIBezierPath bezierPathWithRoundedRect:bodyFrame cornerRadius:self.CCMenuViewOptions.menuCornerRadius];
    
    const CGFloat locations[] = {0, 1};
    const CGFloat components[] = {
        R0, G0, B0, 1,
        R1, G1, B1, 1,
    };
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, sizeof(locations)/sizeof(locations[0]));
    CGColorSpaceRelease(colorSpace);
    
    [borderPath addClip];
    
    CGPoint start, end;
    
    if (_arrowDirection == CCMenuViewArrowDirectionLeft ||
        _arrowDirection == CCMenuViewArrowDirectionRight) {
        
        start = (CGPoint){X0, Y0};
        end = (CGPoint){X1, Y0};
        
    } else {
        
        start = (CGPoint){X0, Y0};
        end = (CGPoint){X0, Y1};
    }
    
    CGContextDrawLinearGradient(context, gradient, start, end, 0);
    
    CGGradientRelease(gradient);
}

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

static CCMenuAccount *gMenu;
static UIColor *gTintColor;
static UIFont *gTitleFont;

@implementation CCMenuAccount {
    
    CCMenuView *_menuView;
    BOOL        _observing;
}

+ (instancetype)sharedMenu
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        gMenu = [[CCMenuAccount alloc] init];
    });
    return gMenu;
}

- (id)init
{
    NSAssert(!gMenu, @"singleton object");
    
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)dealloc
{
    if (_observing) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void)showMenuInView:(UIView *)view fromRect:(CGRect)rect menuItems:(NSArray *)menuItems withOptions:(OptionalConfiguration) options
{
    NSParameterAssert(view);
    NSParameterAssert(menuItems.count);
    
    if (_menuView) {
        
        [_menuView dismissMenu:NO];
        _menuView = nil;
    }
    
    if (!_observing) {
        
        _observing = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationWillChange:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    }
    
    
    _menuView = [[CCMenuView alloc] init];
    [_menuView showMenuInView:view fromRect:rect menuItems:menuItems withOptions:options];
}

- (void)dismissMenu
{
    if (_menuView) {
        
        [_menuView dismissMenu:NO];
        _menuView = nil;
    }
    
    if (_observing) {
        
        _observing = NO;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void)orientationWillChange: (NSNotification *) n
{
    [self dismissMenu];
}

+ (void)showMenuInView:(UIView *)view fromRect:(CGRect)rect menuItems:(NSArray *)menuItems withOptions:(OptionalConfiguration)options
{
    [[self sharedMenu] showMenuInView:view fromRect:rect menuItems:menuItems withOptions:options];
}

+ (void)dismissMenu
{
    [[self sharedMenu] dismissMenu];
}

+ (UIColor *)tintColor
{
    return gTintColor;
}

+ (void)setTintColor:(UIColor *)tintColor
{
    if (tintColor != gTintColor) {
        gTintColor = tintColor;
    }
}

+ (UIFont *)titleFont
{
    return gTitleFont;
}

+ (void)setTitleFont:(UIFont *)titleFont
{
    if (titleFont != gTitleFont) {
        gTitleFont = titleFont;
    }
}

@end
