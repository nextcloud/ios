/*
 
 MIT License (MIT)
 
 Copyright (c) 2015 Clement CN Tsang
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 */

#import <UIKit/UIKit.h>

/**
 *  The label to show selection index.
 */
@interface CTAssetSelectionLabel : UILabel


#pragma mark Customizing Appearance

/**
 *  @name Customizing Appearance
 */

/**
*  Determines whether the label is circular or not. *Deprecated*.
*/
@property (nonatomic, assign, getter=isCircular) BOOL circular UI_APPEARANCE_SELECTOR DEPRECATED_MSG_ATTRIBUTE("Use setCornerRadius: instead.");

/**
 *  The width of the label's border.
 */
@property (nonatomic, assign) CGFloat borderWidth UI_APPEARANCE_SELECTOR;

/**
 *  The color of the label's border.
 */
@property (nonatomic, weak) UIColor *borderColor UI_APPEARANCE_SELECTOR;

/**
 *  To set the size of label.
 *
 *  @param size The size of the label.
 */
- (void)setSize:(CGSize)size UI_APPEARANCE_SELECTOR;

/**
 *  To set the corner radius of label.
 *
 *  @param cornerRadius The radius to use when drawing rounded corners for the label’s background.
 */
- (void)setCornerRadius:(CGFloat)cornerRadius UI_APPEARANCE_SELECTOR;

/**
 *  To set margin of the label from the edges.
 *
 *  @param margin The margin from the edges.
 *
 *  @see setMargin:forVerticalEdge:horizontalEdge:
 */
- (void)setMargin:(CGFloat)margin UI_APPEARANCE_SELECTOR;

/**
 *  To set margin of the label from specific edges.
 *
 *  @param margin The margin from the edges.
 *  @param edgeX  The layout attribute respresents vertical edge that the label pins to. Either `NSLayoutAttributeLeft` or `NSLayoutAttributeRight`.
 *  @param edgeY  The layout attribute respresents horizontal edge that the label pins to. Either `NSLayoutAttributeTop` or `NSLayoutAttributeBottom`.
 *
 *  @see setMargin:
 */
- (void)setMargin:(CGFloat)margin forVerticalEdge:(NSLayoutAttribute)edgeX horizontalEdge:(NSLayoutAttribute)edgeY UI_APPEARANCE_SELECTOR;

/**
 *  To set the text attributes to display the label.
 *
 *  Currently only supports attributes `NSFontAttributeName`, `NSForegroundColorAttributeName` and `NSBackgroundColorAttributeName`.
 *
 *  @param textAttributes The text attributes used to display the label.
 */
- (void)setTextAttributes:(NSDictionary<NSString*, id> *)textAttributes UI_APPEARANCE_SELECTOR;

@end
