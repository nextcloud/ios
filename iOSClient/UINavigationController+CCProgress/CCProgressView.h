//
//  CCProgressView.h
//  CCNavigationProgress
//
//  Created by Marino Faggiana on 22/06/16.
//  Copyright (c) 2016 TWS. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CCProgressView : UIView

/**
 *  The current progress shown by the receiver.
 *  The progress value ranges from 0 to 1. The default value is 0.
 */
@property (nonatomic, assign) float progress;

@end
