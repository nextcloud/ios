#import <UIKit/UIKit.h>

@interface NSLayoutConstraint (PKDownloadButton)

+ (NSArray *)constraintsForWrappedSubview:(UIView *)view withInsets:(UIEdgeInsets)insets;
+ (NSArray *)horizontalConstraintsForWrappedSubview:(UIView *)view withInsets:(UIEdgeInsets)insets;
+ (NSArray *)verticalConstraintsForWrappedSubview:(UIView *)view withInsets:(UIEdgeInsets)insets;
+ (NSLayoutConstraint *)constraintForView:(UIView *)view withWidth:(CGFloat)width;
+ (NSLayoutConstraint *)constraintForView:(UIView *)view withHeight:(CGFloat)height;
+ (NSArray *)constraintsForView:(UIView *)view withSize:(CGSize)size;
+ (NSArray *)constraintsWithVisualFormat:(NSString *)format views:(NSDictionary *)views;
+ (NSLayoutConstraint *)constraintForCenterByYView:(UIView *)overlay withView:(UIView *)view;
+ (NSLayoutConstraint *)constraintForCenterByXView:(UIView *)overlay withView:(UIView *)view;
// Constraints for center view above it's superview
+ (NSArray *)constraintsForCenterView:(UIView *)overlay;
+ (NSArray *)constraintsForCenterView:(UIView *)overlay withView:(UIView *)view;

@end
