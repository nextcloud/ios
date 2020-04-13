//
//  NCAutoUpload+NCUtil.h
//  NextcloudTests
//
//  Created by James Stout on 13/4/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

#import "NCAutoUpload.h"

NS_ASSUME_NONNULL_BEGIN

@interface NCAutoUpload ()
// extension to make the method public
- (PHFetchResult *)getCameraRollAssets:(tableAccount *)account selector:(NSString *)selector alignPhotoLibrary:(BOOL)alignPhotoLibrary;

@end

NS_ASSUME_NONNULL_END
