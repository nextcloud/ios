//
//  CCSection.m
//  Nextcloud
//
//  Created by Marino Faggiana on 04/02/16.
//  Copyright (c) 2016 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

#import "CCSection.h"
#import "CCExifGeo.h"
#import "NCBridgeSwift.h"

@implementation CCSectionDataSourceMetadata

- (id)init {
    
    self = [super init];
    
    _allRecordsDataSource = [[NSMutableDictionary alloc] init];
    _allOcId  = [[NSMutableArray alloc] init];
    _sections = [[NSMutableArray alloc] init];
    _sectionArrayRow = [[NSMutableDictionary alloc] init];
    _ocIdIndexPath = [[NSMutableDictionary alloc] init];
    _metadatas = [NSMutableArray new];
    
    _image = 0;
    _video = 0;
    _directories = 0;
    _files = 0;
    _totalSize = 0;
    
    return self;
}

- (id)copyWithZone: (NSZone *) zone
{
    CCSectionDataSourceMetadata *sectionDataSourceMetadata = [[CCSectionDataSourceMetadata allocWithZone: zone] init];
    
    [sectionDataSourceMetadata setAllRecordsDataSource: self.allRecordsDataSource];
    [sectionDataSourceMetadata setAllOcId: self.allOcId];
    [sectionDataSourceMetadata setSections: self.sections];
    [sectionDataSourceMetadata setSectionArrayRow: self.sectionArrayRow];
    [sectionDataSourceMetadata setOcIdIndexPath: self.ocIdIndexPath];
    [sectionDataSourceMetadata setMetadatas: self.metadatas];

    [sectionDataSourceMetadata setVideo: self.video];
    [sectionDataSourceMetadata setImage: self.image];
    
    [sectionDataSourceMetadata setDirectories: self.directories];
    [sectionDataSourceMetadata setFiles: self.files];
    [sectionDataSourceMetadata setTotalSize: self.totalSize];
    
    return sectionDataSourceMetadata;
}

@end


@implementation CCSectionMetadata

//
// orderByField : nil, date, typeFile
//
+ (CCSectionDataSourceMetadata *)creataDataSourseSectionMetadata:(NSArray *)arrayMetadatas listProgressMetadata:(NSMutableDictionary *)listProgressMetadata groupBy:(NSString *)groupBy filterTypeFileImage:(BOOL)filterTypeFileImage filterTypeFileVideo:(BOOL)filterTypeFileVideo filterLivePhoto:(BOOL)filterLivePhoto sort:(NSString *)sort ascending:(BOOL)ascending directoryOnTop:(BOOL)directoryOnTop account:(NSString *)account
{
    id dataSection;
    
    NSMutableDictionary *dictionaryEtagMetadataForIndexPath = [NSMutableDictionary new];
    CCSectionDataSourceMetadata *sectionDataSource = [CCSectionDataSourceMetadata new];
    NSArray *arraySoprtedMetadatas;
    NSMutableArray *filterocId = [NSMutableArray new];
    
    /*
     Live Photo
    */
    
    if ([CCUtility getLivePhoto] && filterLivePhoto) {
        for (tableMetadata *metadata in arrayMetadatas) {
            if ([metadata.ext isEqualToString:@"mov"] && metadata.livePhoto) {
                [filterocId addObject:metadata.ocId];
            }
        }
    }
    
    /*
     Metadata order
    */
    
    arraySoprtedMetadatas = [arrayMetadatas sortedArrayUsingComparator:^NSComparisonResult(tableMetadata *obj1, tableMetadata *obj2) {
        // Sort with Locale
        if ([sort isEqualToString:@"date"]) {
            if (ascending) return [obj1.date compare:obj2.date];
            else return [obj2.date compare:obj1.date];
        } else if ([sort isEqualToString:@"sessionTaskIdentifier"]) {
            if (ascending) return (obj1.sessionTaskIdentifier < obj2.sessionTaskIdentifier);
            else return (obj1.sessionTaskIdentifier > obj2.sessionTaskIdentifier);
        } else if ([sort isEqualToString:@"size"]) {
            if (ascending) return (obj1.size < obj2.size);
            else return (obj1.size > obj2.size);
        } else {
            if (ascending) return [obj1.fileNameView compare:obj2.fileNameView options:NSCaseInsensitiveSearch range:NSMakeRange(0,[obj1.fileNameView length]) locale:[NSLocale currentLocale]];
            else return [obj2.fileNameView compare:obj1.fileNameView options:NSCaseInsensitiveSearch range:NSMakeRange(0,[obj2.fileNameView length]) locale:[NSLocale currentLocale]];
        }
    }];
    
    /*
     Initialize datasource
    */
    
    NSInteger numDirectory = 0;
    NSInteger numDirectoryFavorite = 0;
    NSMutableArray *metadataFilesFavorite = [NSMutableArray new];
    
    for (tableMetadata *metadata in arraySoprtedMetadatas) {
        
        // *** LIST : DO NOT INSERT ***
        if ([filterocId containsObject: metadata.ocId] || (filterTypeFileImage == YES && [metadata.typeFile isEqualToString: k_metadataTypeFile_image]) || (filterTypeFileVideo == YES && [metadata.typeFile isEqualToString: k_metadataTypeFile_video])) {
            continue;
        }
        
        if ([listProgressMetadata objectForKey:metadata.ocId] && [groupBy isEqualToString:@"session"]) {
            
            [sectionDataSource.metadatas insertObject:metadata atIndex:0];
            
        } else {
            
            if (metadata.directory && directoryOnTop) {
                if (metadata.favorite) {
                    [sectionDataSource.metadatas insertObject:metadata atIndex:numDirectoryFavorite++];
                    numDirectory++;
                } else {
                    [sectionDataSource.metadatas insertObject:metadata atIndex:numDirectory++];
                }
            } else {
                if (metadata.favorite && directoryOnTop) {
                    [metadataFilesFavorite addObject:metadata];
                } else {
                    [sectionDataSource.metadatas addObject:metadata];
                }
            }
        }
    }
    if (directoryOnTop && metadataFilesFavorite.count > 0) {
        [sectionDataSource.metadatas insertObjects:metadataFilesFavorite atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(numDirectoryFavorite, metadataFilesFavorite.count)]]; // Add Favorite files at end of favorite folders
    }
    
    /*
     sectionArrayRow
    */
    
    for (tableMetadata *metadata in  sectionDataSource.metadatas) {
        
        if ([metadata.session length] > 0 && [groupBy isEqualToString:@"session"]) {
            
            if ([metadata.session containsString:@"wwan"]) dataSection = [@"." stringByAppendingString:metadata.session];
            else dataSection = metadata.session;
        }
        else if ([groupBy isEqualToString:@"none"]) dataSection = @"_none_";
        else if ([groupBy isEqualToString:@"date"]) dataSection = [CCUtility datetimeWithOutTime:metadata.date];
        else if ([groupBy isEqualToString:@"alphabetic"]) dataSection = [[metadata.fileNameView substringToIndex:1] uppercaseString];
        else if ([groupBy isEqualToString:@"typefile"]) dataSection = metadata.typeFile;
        if (!dataSection) dataSection = @"_none_";
        
        NSMutableArray *metadatasSection = [sectionDataSource.sectionArrayRow objectForKey:dataSection];
        
        if (metadatasSection) {
            
            // ROW ++
            [metadatasSection addObject:metadata.ocId];
            [sectionDataSource.sectionArrayRow setObject:metadatasSection forKey:dataSection];
            
        } else {
            
            // SECTION ++
            metadatasSection = [[NSMutableArray alloc] initWithObjects:metadata.ocId, nil];
            [sectionDataSource.sectionArrayRow setObject:metadatasSection forKey:dataSection];
        }

        if (metadata && [metadata.ocId length] > 0)
            [dictionaryEtagMetadataForIndexPath setObject:metadata forKey:metadata.ocId];
    }
    
    /*
    Sections order
    */
    
    /*
    BOOL ascending;
    
    if ([groupByField isEqualToString:@"date"]) ascending = NO;
    else ascending = YES;
    */
    
    NSArray *sortSections = [[sectionDataSource.sectionArrayRow allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        
        if ([groupBy isEqualToString:@"session"]) {
        
            if ([obj1 isKindOfClass:[NSString class]] && [obj1 containsString:@"download"]) return NSOrderedAscending;
            if ([obj2 isKindOfClass:[NSString class]] && [obj2 containsString:@"download"]) return NSOrderedDescending;
        
            if ([obj1 isKindOfClass:[NSString class]] && [obj1 containsString:@"upload"]) return NSOrderedAscending;
            if ([obj2 isKindOfClass:[NSString class]] && [obj2 containsString:@"upload"]) return NSOrderedDescending;
        }
        
        // Directory at Top
        if ([obj1 isKindOfClass:[NSString class]] && [obj1 containsString: k_metadataTypeFile_directory]) return NSOrderedAscending;
        if ([obj2 isKindOfClass:[NSString class]] && [obj2 containsString: k_metadataTypeFile_directory]) return NSOrderedDescending;
        
        // Sort with Locale
        if ([obj1 isKindOfClass:[NSDate class]]) {
            if (ascending) return [obj1 compare:obj2];
            else return [obj2 compare:obj1];
        } else {
            if (ascending) return [obj1 compare:obj2 options:NSCaseInsensitiveSearch range:NSMakeRange(0,[obj1 length]) locale:[NSLocale currentLocale]];
            else return [obj2 compare:obj1 options:NSCaseInsensitiveSearch range:NSMakeRange(0,[obj2 length]) locale:[NSLocale currentLocale]];
        }
    }];
    
    /*
    create allEtag, allRecordsDataSource, ocIdIndexPath, section
    */
    
    NSInteger indexSection = 0;
    NSInteger indexRow = 0;
    
    for (id section in sortSections) {
        
        [sectionDataSource.sections addObject:section];
        
        NSArray *rows = [sectionDataSource.sectionArrayRow objectForKey:section];
        
        for (NSString *ocId in rows) {
            
            tableMetadata *metadata = [dictionaryEtagMetadataForIndexPath objectForKey:ocId];
            
            if (metadata.ocId) {
                
                [sectionDataSource.allOcId addObject:metadata.ocId];
                [sectionDataSource.allRecordsDataSource setObject:metadata forKey:metadata.ocId];
                [sectionDataSource.ocIdIndexPath setObject:[NSIndexPath indexPathForRow:indexRow inSection:indexSection] forKey:metadata.ocId];
                
                if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
                    sectionDataSource.image++;
                if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video])
                    sectionDataSource.video++;
                if (metadata.directory)
                    sectionDataSource.directories++;
                else {
                    sectionDataSource.files++;
                    sectionDataSource.totalSize = sectionDataSource.totalSize + metadata.size;
                }
                
                indexRow++;
            }
        }
        indexSection++;
        indexRow = 0;
    }
    
    /*
    end
    */
    
    return sectionDataSource;
}

+ (void)removeAllObjectsSectionDataSource:(CCSectionDataSourceMetadata *)sectionDataSource
{
    [sectionDataSource.allRecordsDataSource removeAllObjects];
    [sectionDataSource.allOcId removeAllObjects];
    [sectionDataSource.sections removeAllObjects];
    [sectionDataSource.sectionArrayRow removeAllObjects];
    [sectionDataSource.ocIdIndexPath removeAllObjects];
    
    sectionDataSource.image = 0;
    sectionDataSource.video = 0;
    sectionDataSource.directories = 0;
    sectionDataSource.files = 0;
    sectionDataSource.totalSize = 0;
}

@end


@implementation CCSectionDataSourceActivity

- (id)init {
    
    self = [super init];
    
    _sections = [NSMutableArray new];
    _sectionArrayRow = [NSMutableDictionary new];

    return self;
}

@end

@implementation CCSectionActivity

+ (CCSectionDataSourceActivity *)creataDataSourseSectionActivity:(NSArray *)records account:(NSString *)account
{
    CCSectionDataSourceActivity *sectionDataSource = [CCSectionDataSourceActivity new];
    NSDate *oldDate = [NSDate date];
    
    for (tableActivity *record in records) {
        
        NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:record.date];
        NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:comps];
        
        if ([oldDate compare:date] != NSOrderedSame) {
            
            [sectionDataSource.sections addObject:date];
            oldDate = date;
        }
        
        NSMutableArray *activities = [sectionDataSource.sectionArrayRow objectForKey:date];
        
        if (activities) {
            
            // ROW ++
            [activities addObject:record];
            [sectionDataSource.sectionArrayRow setObject:activities forKey:date];
            
        } else {
            
            // SECTION ++
            activities = [[NSMutableArray alloc] initWithObjects:record, nil];
            [sectionDataSource.sectionArrayRow setObject:activities forKey:date];
        }
    }
    
    return sectionDataSource;
}

@end



