//
//  PhotoViewController.h
//  DBRoulette
//
//  Created by Brian Smith on 7/7/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//


@class DBRestClient;

@interface PhotoViewController : UIViewController {
    UIImageView* imageView;
    UIButton* nextButton;
    UIActivityIndicatorView* activityIndicator;
    
    NSArray* photoPaths;
    NSString* photosHash;
    NSString* currentPhotoPath;
    BOOL working;
    DBRestClient* restClient;
}

@property (nonatomic, retain) IBOutlet UIImageView* imageView;
@property (nonatomic, retain) IBOutlet UIButton* nextButton;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView* activityIndicator;

@end
