//
//  OCCapabilities.h
//  ownCloud iOS library
//
//  Created by Gonzalo Gonzalez on 4/11/15.
//  Copyright © 2015 ownCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OCCapabilities : NSObject

/*VERSION*/
@property (nonatomic) NSInteger versionMajor;
@property (nonatomic) NSInteger versionMinor;
@property (nonatomic) NSInteger versionMicro;
@property (nonatomic, strong) NSString *versionString;
@property (nonatomic, strong) NSString *versionEdition;

/*CAPABILITIES*/

/*CORE*/
@property (nonatomic) NSInteger corePollInterval;
@property (nonatomic, strong) NSString *coreWebDavRoot;

/*FILES SHARING*/

@property (nonatomic) BOOL isFilesSharingAPIEnabled;
@property (nonatomic) NSInteger filesSharingDefaulPermissions;
@property (nonatomic) BOOL isFilesSharingGroupSharing;
@property (nonatomic) BOOL isFilesSharingReSharing;

//FILE SHARING - PUBLIC

@property (nonatomic) BOOL isFilesSharingPublicShareLinkEnabled;
@property (nonatomic) BOOL isFilesSharingAllowPublicUploadsEnabled;
@property (nonatomic) BOOL isFilesSharingAllowPublicUserSendMail;
@property (nonatomic) BOOL isFilesSharingAllowPublicUploadFilesDrop;
@property (nonatomic) BOOL isFilesSharingAllowPublicMultipleLinks;

@property (nonatomic) BOOL isFilesSharingPublicExpireDateByDefaultEnabled;
@property (nonatomic) BOOL isFilesSharingPublicExpireDateEnforceEnabled;
@property (nonatomic) NSInteger filesSharingPublicExpireDateDays;

@property (nonatomic) BOOL isFilesSharingPublicPasswordEnforced;

//FILE SHARING - USER

@property (nonatomic) BOOL isFilesSharingAllowUserSendMail;
@property (nonatomic) BOOL isFilesSharingUserExpireDate;

//FILE SHARING - GROUP

@property (nonatomic) BOOL isFilesSharingGroupEnabled;
@property (nonatomic) BOOL isFilesSharingGroupExpireDate;

//FILE SHARING - FEDERATION

@property (nonatomic) BOOL isFilesSharingFederationAllowUserSendShares;
@property (nonatomic) BOOL isFilesSharingFederationAllowUserReceiveShares;
@property (nonatomic) BOOL isFilesSharingFederationExpireDate;

//FILE SHARING - SHAREBYMAIL

@property (nonatomic) BOOL isFileSharingShareByMailEnabled;
@property (nonatomic) BOOL isFileSharingShareByMailExpireDate;
@property (nonatomic) BOOL isFileSharingShareByMailPassword;
@property (nonatomic) BOOL isFileSharingShareByMailUploadFilesDrop;

// External sites
@property (nonatomic) BOOL isExternalSitesServerEnabled;
@property (nonatomic, strong) NSString *externalSiteV1;

// Notification
@property (nonatomic) BOOL isNotificationServerEnabled;
@property (nonatomic, strong) NSString *notificationOcsEndpoints;
@property (nonatomic, strong) NSString *notificationPush;

// Spreed
@property (nonatomic) BOOL isSpreedServerEnabled;
@property (nonatomic, strong) NSString *spreedFeatures;

/*FILES*/
@property (nonatomic) BOOL isFileBigFileChunkingEnabled;
@property (nonatomic) BOOL isFileUndeleteEnabled;
@property (nonatomic) BOOL isFileVersioningEnabled;

// Theming
@property (nonatomic, strong) NSString *themingBackground;
@property (nonatomic) BOOL themingBackgroundDefault;
@property (nonatomic) BOOL themingBackgroundPlain;
@property (nonatomic, strong) NSString *themingColor;
@property (nonatomic, strong) NSString *themingColorElement;
@property (nonatomic, strong) NSString *themingColorText;
@property (nonatomic, strong) NSString *themingLogo;
@property (nonatomic, strong) NSString *themingName;
@property (nonatomic, strong) NSString *themingSlogan;
@property (nonatomic, strong) NSString *themingUrl;

// End to End Encryption
@property (nonatomic) BOOL isEndToEndEncryptionEnabled;
@property (nonatomic, strong) NSString *endToEndEncryptionVersion;

// Richdocuments
@property (nonatomic, strong) NSArray *richdocumentsMimetypes;
@property (nonatomic) BOOL richdocumentsDirectEditing;

// Activity
@property (nonatomic) BOOL isActivityV2Enabled;
@property (nonatomic, strong) NSString *activityV2;

// HC
@property (nonatomic) BOOL isHandwerkcloudEnabled;
@property (nonatomic, strong) NSString *HCShopUrl;

// Imagemeter
@property (nonatomic) BOOL isImagemeterEnabled;

// Fulltextsearch
@property (nonatomic) BOOL isFulltextsearchEnabled;

// Extended Support
@property (nonatomic) BOOL isExtendedSupportEnabled;

// Pagination
@property (nonatomic) BOOL isPaginationEnabled;
@property (nonatomic, strong) NSString *paginationEndponit;

@end
