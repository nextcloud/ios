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

#import <UIKit/UIKit.h>

@interface CCMenuItem : NSObject

@property (readwrite, nonatomic, strong) UIImage *image;
@property (readwrite, nonatomic, strong) NSString *title;
@property (readwrite, nonatomic, strong) NSString *argument;
@property (readwrite, nonatomic, weak) id target;
@property (readwrite, nonatomic) SEL action;
@property (readwrite, nonatomic, strong) UIColor *foreColor;
@property (readwrite, nonatomic) NSTextAlignment alignment;

+ (instancetype)menuItem:(NSString *)title argument:(NSString*)argument image:(UIImage *)image target:(id)target action:(SEL)action;

@end

typedef struct {
    
    CGFloat R;
    CGFloat G;
    CGFloat B;

} Color;

typedef struct {
    
    CGFloat arrowSize;
    CGFloat marginXSpacing;
    CGFloat marginYSpacing;
    CGFloat intervalSpacing;
    CGFloat menuCornerRadius;
    Boolean maskToBackground;
    Boolean shadowOfMenu;
    Boolean hasSeperatorLine;
    Boolean seperatorLineHasInsets;
    Color textColor;
    Color menuBackgroundColor;
    
} OptionalConfiguration;

@interface CCMenuView : UIView

@property (atomic, assign) OptionalConfiguration CCMenuViewOptions;

@end

@interface CCMenuAccount : NSObject

+ (void)showMenuInView:(UIView *)view fromRect:(CGRect)rect menuItems:(NSArray *)menuItems withOptions:(OptionalConfiguration)options;

+ (void)dismissMenu;

+ (UIColor *)tintColor;
+ (void)setTintColor:(UIColor *)tintColor;

+ (UIFont *)titleFont;
+ (void)setTitleFont:(UIFont *)titleFont;

@end
