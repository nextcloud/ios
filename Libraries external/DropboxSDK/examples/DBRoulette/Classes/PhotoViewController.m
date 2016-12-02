//
//  PhotoViewController.m
//  DBRoulette
//
//  Created by Brian Smith on 7/7/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

#import "PhotoViewController.h"
#import <DropboxSDK/DropboxSDK.h>
#import <stdlib.h>


@interface PhotoViewController () <DBRestClientDelegate>

- (NSString*)photoPath;
- (void)didPressRandomPhoto;
- (void)loadRandomPhoto;
- (void)displayError;
- (void)setWorking:(BOOL)isWorking;

@property (nonatomic, readonly) DBRestClient* restClient;

@end


@implementation PhotoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Random Photo";
    [nextButton addTarget:self action:@selector(didPressRandomPhoto) 
            forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewDidUnload {
    [super viewDidUnload];
   
    self.imageView = nil;
    self.nextButton = nil;
    self.activityIndicator = nil;
}

- (void)dealloc {
    [imageView release];
    [nextButton release];
    [activityIndicator release];
    [photoPaths release];
    [photosHash release];
    [currentPhotoPath release];
    [restClient release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!working && !imageView.image) {
        [self didPressRandomPhoto];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [restClient release];
    restClient = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        return toInterfaceOrientation == UIInterfaceOrientationPortrait;
    } else {
        return YES;
    }
}

@synthesize imageView;
@synthesize nextButton;
@synthesize activityIndicator;


#pragma mark DBRestClientDelegate methods

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata {
    [photosHash release];
    photosHash = [metadata.hash retain];
    
    NSArray* validExtensions = [NSArray arrayWithObjects:@"jpg", @"jpeg", nil];
    NSMutableArray* newPhotoPaths = [NSMutableArray new];
    for (DBMetadata* child in metadata.contents) {
        NSString* extension = [[child.path pathExtension] lowercaseString];
        if (!child.isDirectory && [validExtensions indexOfObject:extension] != NSNotFound) {
            [newPhotoPaths addObject:child.path];
        }
    }
    [photoPaths release];
    photoPaths = newPhotoPaths;
    [self loadRandomPhoto];
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path {
    [self loadRandomPhoto];
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error {
    NSLog(@"restClient:loadMetadataFailedWithError: %@", [error localizedDescription]);
    [self displayError];
    [self setWorking:NO];
}

- (void)restClient:(DBRestClient*)client loadedThumbnail:(NSString*)destPath {
    [self setWorking:NO];
    imageView.image = [UIImage imageWithContentsOfFile:destPath];
}

- (void)restClient:(DBRestClient*)client loadThumbnailFailedWithError:(NSError*)error {
    [self setWorking:NO];
    [self displayError];
}


#pragma mark private methods

- (void)didPressRandomPhoto {
    [self setWorking:YES];

    NSString *photosRoot = nil;
    if ([DBSession sharedSession].root == kDBRootDropbox) {
        photosRoot = @"/Photos";
    } else {
        photosRoot = @"/";
    }

    [self.restClient loadMetadata:photosRoot withHash:photosHash];
}

- (void)loadRandomPhoto {
    if ([photoPaths count] == 0) {

        NSString *msg = nil;
        if ([DBSession sharedSession].root == kDBRootDropbox) {
            msg = @"Put .jpg photos in your Photos folder to use DBRoulette!";
        } else {
            msg = @"Put .jpg photos in your app's App folder to use DBRoulette!";
        }

        [[[[UIAlertView alloc] 
           initWithTitle:@"No Photos!" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]
          autorelease]
         show];
        
        [self setWorking:NO];
    } else {
        NSString* photoPath;
        if ([photoPaths count] == 1) {
            photoPath = [photoPaths objectAtIndex:0];
            if ([photoPath isEqual:currentPhotoPath]) {
                [[[[UIAlertView alloc]
                   initWithTitle:@"No More Photos" message:@"You only have one photo to display." 
                   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]
                  autorelease]
                 show];
                
                [self setWorking:NO];
                return;
            }
        } else {
            // Find a random photo that is not the current photo
            do {
                srandom((unsigned int)time(NULL));
                NSInteger index =  random() % [photoPaths count];
                photoPath = [photoPaths objectAtIndex:index];
            } while ([photoPath isEqual:currentPhotoPath]);
        }
        
        [currentPhotoPath release];
        currentPhotoPath = [photoPath retain];
        
        [self.restClient loadThumbnail:currentPhotoPath ofSize:@"iphone_bestfit" intoPath:[self photoPath]];
    }
}

- (NSString*)photoPath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"photo.jpg"];
}

- (void)displayError {
    [[[[UIAlertView alloc] 
       initWithTitle:@"Error Loading Photo" message:@"There was an error loading your photo." 
       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]
      autorelease]
     show];
}

- (void)setWorking:(BOOL)isWorking {
    if (working == isWorking) return;
    working = isWorking;
    
    if (working) {
        [activityIndicator startAnimating];
    } else { 
        [activityIndicator stopAnimating];
    }
    nextButton.enabled = !working;
}

- (DBRestClient*)restClient {
    if (restClient == nil) {
        restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        restClient.delegate = self;
    }
    return restClient;
}

@end
