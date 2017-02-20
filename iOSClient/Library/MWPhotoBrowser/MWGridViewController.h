//
//  MWGridViewController.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 08/10/2013.
//
//

#import <UIKit/UIKit.h>
#import "MWPhotoBrowser.h"

@interface MWGridViewController : UICollectionViewController {}

@property (nonatomic, assign) MWPhotoBrowser *browser;
@property (nonatomic) BOOL selectionMode;
@property (nonatomic) CGPoint initialContentOffset;

- (void)adjustOffsetsAsRequired;

//TWS
- (BOOL)visibleGridIndexPath:(NSUInteger)index;
- (void)reloadItem:(NSUInteger)index;


@end
