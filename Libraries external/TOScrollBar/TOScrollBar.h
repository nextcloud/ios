//
//  TOScrollBar.h
//
//  Copyright 2016-2017 Timothy Oliver. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import <UIKit/UIKit.h>
#import "UIScrollView+TOScrollBar.h"

typedef NS_ENUM(NSInteger, TOScrollBarStyle) {
    TOScrollBarStyleDefault,
    TOScrollBarStyleDark
};

NS_ASSUME_NONNULL_BEGIN

@interface TOScrollBar : UIView

/* The visual style of the scroll bar, either light or dark */
@property (nonatomic, assign) TOScrollBarStyle style;

/** Aligns the scroll bar to the top of the scroll view content offset.
     Set this to `YES` when using this in a view controller with iOS 11 large titles. */
@property (nonatomic, assign) BOOL insetForLargeTitles;

/** The amount of padding above and below the scroll bar (Only top and bottom values are counted. Default is {20,20} ) */
@property (nonatomic, assign) UIEdgeInsets verticalInset;

/** The inset, in points of the middle of track from the edge of the scroll view */
@property (nonatomic, assign) CGFloat edgeInset;

/** The tint color of the track */
@property (nonatomic, strong) UIColor *trackTintColor;

/** The width in points, of the track (Default value is 2.0) */
@property (nonatomic, assign) CGFloat trackWidth;

/** The tint color of the handle (Defaults to the system tint color) */
@property (nonatomic, strong, nullable) UIColor *handleTintColor;

/** The width in points, of the handle. (Default value is 4.0) */
@property (nonatomic, assign) CGFloat handleWidth;

/** The minimum height in points the handle may be in relation to the content height. (Default value is 64.0) */
@property (nonatomic, assign) CGFloat handleMinimiumHeight;

/** The user is currently dragging the handle */
@property (nonatomic, assign, readonly) BOOL dragging;

/** The minimum required scale of the scroll view's content height before the scroll bar is shown (Default is 5.0) */
@property (nonatomic, assign) CGFloat minimumContentHeightScale;

/** The scroll view in which this scroll bar has been added. */
@property (nonatomic, weak, readonly) UIScrollView *scrollView;

/** When enabled, the scroll bar will only respond to direct touches to the handle control.
 Touches to the track will be passed to the UI controls beneath it.
 Default is NO. */
@property (nonatomic, assign) BOOL handleExclusiveInteractionEnabled;

/** 
 Creates a new instance of the scroll bar view 
 
 @param style The initial style of the scroll bar upon creation
 */
- (instancetype)initWithStyle:(TOScrollBarStyle)style;

/**
 Adds the scroll bar to a scroll view
 
 @param scrollView The scroll view that will receive this scroll bar
 */
- (void)addToScrollView:(UIScrollView *)scrollView;

/**
 Removes the scroll bar from the scroll view and resets the scroll view's state
 */
- (void)removeFromScrollView;

/**
 If added to a table view, this convienience method will compute the appropriate
 inset values for the table separator so they don't underlap the scroll bar
 
 @param inset The original separator inset value of the table view
 */
- (UIEdgeInsets)adjustedTableViewSeparatorInsetForInset:(UIEdgeInsets)inset;

/**
 If added to a table view, this convienience method will compute the appropriate
 insets values for each cell's layout margins in order to appropriately push the cell's
 content inwards
 
 @param layoutMargins The current `layoutMargins` value of the `UITableViewCell` instance.
 @param offset If desired, any additional horizontal offset for this specific use case
 
 */
- (UIEdgeInsets)adjustedTableViewCellLayoutMarginsForMargins:(UIEdgeInsets)layoutMargins manualOffset:(CGFloat)offset;

/**
 Shows or hides the scroll bar from the scroll view with an optional animation
 */
- (void)setHidden:(BOOL)hidden animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

