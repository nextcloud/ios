//
//  CCOfflinePageContent.h
//  Nextcloud
//
//  Created by Marino Faggiana on 01/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CCDetail.h"
#import "UIScrollView+EmptyDataSet.h"
#import "TWMessageBarManager.h"
#import "AHKActionSheet.h"
#import "CCCellOffline.h"
#import "CCUtility.h"
#import "CCCoreData.h"
#import "CCMain.h"
#import "CCGraphics.h"
#import "CCAccountWeb.h"
#import "CCBancomat.h"
#import "CCCartaDiCredito.h"
#import "CCCartaIdentita.h"
#import "CCContoCorrente.h"
#import "CCNote.h"
#import "CCPassaporto.h"
#import "CCPatenteGuida.h"

@interface CCOfflinePageContent : UITableViewController <UITableViewDataSource, UITableViewDelegate, UIDocumentInteractionControllerDelegate, UIActionSheetDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, CCAccountWebDelegate, CCBancomatDelegate, CCCartaDiCreditoDelegate, CCCartaIdentitaDelegate, CCContoCorrenteDelegate, CCNoteDelegate, CCPassaportoDelegate, CCPatenteGuidaDelegate>

@property NSUInteger pageIndex;
@property (nonatomic, strong) NSString *pageType;


@property (nonatomic, strong) CCMetadata *metadata;
@property (nonatomic, strong) NSString *fileIDPhoto;
@property (nonatomic, strong) NSString *directoryIDPhoto;

@property (nonatomic, strong) NSString *localServerUrl;

@property (nonatomic, weak) CCDetail *detailViewController;
@property (nonatomic, strong) UIDocumentInteractionController *docController;

@end
