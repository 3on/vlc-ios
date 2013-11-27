/*****************************************************************************
 * VLCLocalServerFolderListViewController.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *          Pierre SAGASPE <pierre.sagaspe # me.com>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCLocalServerFolderListViewController.h"
#import "MediaServerBasicObjectParser.h"
#import "MediaServer1ItemObject.h"
#import "MediaServer1ContainerObject.h"
#import "MediaServer1Device.h"
#import "VLCLocalNetworkListCell.h"
#import "VLCAppDelegate.h"
#import "VLCPlaylistViewController.h"
#import "UINavigationController+Theme.h"
#import "VLCDownloadViewController.h"
#import "WhiteRaccoon.h"
#import "NSString+SupportedMedia.h"
#import "VLCStatusLabel.h"

#define kVLCServerTypeUPNP 0
#define kVLCServerTypeFTP 1

@interface VLCLocalServerFolderListViewController () <UITableViewDataSource, UITableViewDelegate, WRRequestDelegate, VLCLocalNetworkListCell, UISearchBarDelegate, UISearchDisplayDelegate>
{
    /* UI */
    UIBarButtonItem *_backButton;

    /* generic data storage */
    NSString *_listTitle;
    NSArray *_objectList;
    NSMutableArray *_mutableObjectList;
    NSUInteger _serverType;

    /* UPNP specifics */
    MediaServer1Device *_UPNPdevice;
    NSString *_UPNProotID;

    /* FTP specifics */
    NSString *_ftpServerAddress;
    NSString *_ftpServerUserName;
    NSString *_ftpServerPassword;
    NSString *_ftpServerPath;
    WRRequestListDirectory *_FTPListDirRequest;

    NSMutableArray *_searchData;
    UISearchBar *_searchBar;
    UISearchDisplayController *_searchDisplayController;
}

@end

@implementation VLCLocalServerFolderListViewController

- (void)loadView
{
    _tableView = [[UITableView alloc] initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStylePlain];
    _tableView.backgroundColor = [UIColor colorWithWhite:.122 alpha:1.];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = [VLCLocalNetworkListCell heightOfCell];
    self.view = _tableView;
}

- (id)initWithUPNPDevice:(MediaServer1Device*)device header:(NSString*)header andRootID:(NSString*)rootID
{
    self = [super init];

    if (self) {
        _UPNPdevice = device;
        _listTitle = header;
        _UPNProotID = rootID;
        _serverType = kVLCServerTypeUPNP;
        _mutableObjectList = [[NSMutableArray alloc] init];
    }

    return self;
}

- (id)initWithFTPServer:(NSString *)serverAddress userName:(NSString *)username andPassword:(NSString *)password atPath:(NSString *)path
{
    self = [super init];

    if (self) {
        _ftpServerAddress = serverAddress;
        _ftpServerUserName = username;
        _ftpServerPassword = password;
        _ftpServerPath = path;
        _serverType = kVLCServerTypeFTP;
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (_serverType == kVLCServerTypeUPNP) {
        NSMutableString *outResult = [[NSMutableString alloc] init];
        NSMutableString *outNumberReturned = [[NSMutableString alloc] init];
        NSMutableString *outTotalMatches = [[NSMutableString alloc] init];
        NSMutableString *outUpdateID = [[NSMutableString alloc] init];

        [[_UPNPdevice contentDirectory] BrowseWithObjectID:_UPNProotID BrowseFlag:@"BrowseDirectChildren" Filter:@"*" StartingIndex:@"0" RequestedCount:@"0" SortCriteria:@"+dc:title" OutResult:outResult OutNumberReturned:outNumberReturned OutTotalMatches:outTotalMatches OutUpdateID:outUpdateID];

        [_mutableObjectList removeAllObjects];
        NSData *didl = [outResult dataUsingEncoding:NSUTF8StringEncoding];
        MediaServerBasicObjectParser *parser = [[MediaServerBasicObjectParser alloc] initWithMediaObjectArray:_mutableObjectList itemsOnly:NO];
        [parser parseFromData:didl];
    } else if (_serverType == kVLCServerTypeFTP) {
        if ([_ftpServerPath isEqualToString:@"/"])
            _listTitle = _ftpServerAddress;
        else
            _listTitle = [_ftpServerPath lastPathComponent];
        [self _listFTPDirectory];
    }

    self.tableView.separatorColor = [UIColor colorWithWhite:.122 alpha:1.];
    self.view.backgroundColor = [UIColor colorWithWhite:.122 alpha:1.];

    self.title = _listTitle;

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    _searchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:_searchBar contentsController:self];
    _searchDisplayController.delegate = self;
    _searchDisplayController.searchResultsDataSource = self;
    _searchDisplayController.searchResultsDelegate = self;
    _searchBar.delegate = self;
    self.tableView.tableHeaderView = _searchBar; //this line add the searchBar on the top of tableView.

    _searchData = [[NSMutableArray alloc] init];
    [_searchData removeAllObjects];

}

- (BOOL)shouldAutorotate
{
    UIInterfaceOrientation toInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
        return NO;
    return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.searchDisplayController.searchResultsTableView)
        return _searchData.count;
	else {
        if (_serverType == kVLCServerTypeUPNP)
            return _mutableObjectList.count;

        return _objectList.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"LocalNetworkCellDetail";

    VLCLocalNetworkListCell *cell = (VLCLocalNetworkListCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
        cell = [VLCLocalNetworkListCell cellWithReuseIdentifier:CellIdentifier];

    if (_serverType == kVLCServerTypeUPNP) {
        MediaServer1BasicObject *item;
        if (tableView == self.searchDisplayController.searchResultsTableView)
            item = _searchData[indexPath.row];
        else
            item = _mutableObjectList[indexPath.row];

        if (![item isContainer]) {
            MediaServer1ItemObject *mediaItem;
            if (tableView == self.searchDisplayController.searchResultsTableView)
                mediaItem = _searchData[indexPath.row];
            else
                mediaItem = _mutableObjectList[indexPath.row];

            [cell setSubtitle: [NSString stringWithFormat:@"%0.2f MB  (%@)", (float)([mediaItem.size intValue] / 1e6), mediaItem.duration]];
            [cell setIsDirectory:NO];
            cell.isDownloadable = YES;
            if (![mediaItem.albumArt isEqualToString:NULL]) {
                NSData* imageData = [[NSData alloc]initWithContentsOfURL:[NSURL URLWithString:mediaItem.albumArt]];
                UIImage* image = [[UIImage alloc] initWithData:imageData];
                [cell setIcon:image];
            }
            else
                [cell setIcon:[UIImage imageNamed:@"blank"]];
            cell.delegate = self;
        } else {
            [cell setIsDirectory:YES];
            [cell setIcon:[UIImage imageNamed:@"folder"]];
        }
        [cell setTitle:[item title]];
    } else if (_serverType == kVLCServerTypeFTP) {
        NSMutableArray *ObjList = [[NSMutableArray alloc] init];
        [ObjList removeAllObjects];

        if (tableView == self.searchDisplayController.searchResultsTableView)
            [ObjList addObjectsFromArray:_searchData];
        else
            [ObjList addObjectsFromArray:_objectList];

        cell.title = [ObjList[indexPath.row] objectForKey:(id)kCFFTPResourceName];

        if ([[ObjList[indexPath.row] objectForKey:(id)kCFFTPResourceType] intValue] == 4) {
            cell.isDirectory = YES;
            cell.icon = [UIImage imageNamed:@"folder"];
        } else {
            cell.isDirectory = NO;
            cell.icon = [UIImage imageNamed:@"blank"];
            cell.subtitle = [NSString stringWithFormat:@"%0.2f MB", (float)([[ObjList[indexPath.row] objectForKey:(id)kCFFTPResourceSize] intValue] / 1e6)];
            cell.isDownloadable = YES;
            cell.delegate = self;
        }
    }
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = (indexPath.row % 2 == 0)? [UIColor blackColor]: [UIColor colorWithWhite:.122 alpha:1.];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_serverType == kVLCServerTypeUPNP) {
        MediaServer1BasicObject *item;
        if (tableView == self.searchDisplayController.searchResultsTableView)
            item = _searchData[indexPath.row];
        else
            item = _mutableObjectList[indexPath.row];

        if ([item isContainer]) {
            MediaServer1ContainerObject *container;
            if (tableView == self.searchDisplayController.searchResultsTableView)
                container = _searchData[indexPath.row];
            else
                container = _mutableObjectList[indexPath.row];

            VLCLocalServerFolderListViewController *targetViewController = [[VLCLocalServerFolderListViewController alloc] initWithUPNPDevice:_UPNPdevice header:[container title] andRootID:[container objectID]];
            [[self navigationController] pushViewController:targetViewController animated:YES];
        } else {
            MediaServer1ItemObject *item;
            if (tableView == self.searchDisplayController.searchResultsTableView)
                item = _searchData[indexPath.row];
            else
                item = _mutableObjectList[indexPath.row];

            MediaServer1ItemRes *resource = nil;
            NSEnumerator *e = [[item resources] objectEnumerator];
            NSURL *itemURL;
            while((resource = (MediaServer1ItemRes*)[e nextObject])){
                APLog(@"%@ - %d, %@, %d, %lld, %d, %@ (%@)", [item title], [resource bitrate], [resource duration], [resource nrAudioChannels], [resource size],  [resource durationInSeconds],  [resource protocolInfo], [item uri]);
                itemURL = [NSURL URLWithString:[item uri]];
            }

            if (itemURL && ([itemURL.scheme isEqualToString:@"http"] || [itemURL.scheme isEqualToString:@"rtsp"] || [itemURL.scheme isEqualToString:@"rtp"] || [itemURL.scheme isEqualToString:@"mms"] || [itemURL.scheme isEqualToString:@"mmsh"])) {
                VLCAppDelegate* appDelegate = [UIApplication sharedApplication].delegate;
                [appDelegate openMovieFromURL:itemURL];
            }
        }
    } else if (_serverType == kVLCServerTypeFTP) {
        NSMutableArray *ObjList = [[NSMutableArray alloc] init];
        [ObjList removeAllObjects];

        if (tableView == self.searchDisplayController.searchResultsTableView)
            [ObjList addObjectsFromArray:_searchData];
        else
            [ObjList addObjectsFromArray:_objectList];

        if ([[ObjList[indexPath.row] objectForKey:(id)kCFFTPResourceType] intValue] == 4) {
            NSString *newPath = [NSString stringWithFormat:@"%@/%@", _ftpServerPath, [ObjList[indexPath.row] objectForKey:(id)kCFFTPResourceName]];

            VLCLocalServerFolderListViewController *targetViewController = [[VLCLocalServerFolderListViewController alloc] initWithFTPServer:_ftpServerAddress userName:_ftpServerUserName andPassword:_ftpServerPassword atPath:newPath];
            [self.navigationController pushViewController:targetViewController animated:YES];
        } else {
            NSString *objectName = [ObjList[indexPath.row] objectForKey:(id)kCFFTPResourceName];
            if (![objectName isSupportedFormat]) {
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FILE_NOT_SUPPORTED", @"") message:[NSString stringWithFormat:NSLocalizedString(@"FILE_NOT_SUPPORTED_LONG", @""), objectName] delegate:self cancelButtonTitle:NSLocalizedString(@"BUTTON_CANCEL", @"") otherButtonTitles:nil];
                [alert show];
            } else
                [self _openURLStringAndDismiss:[_FTPListDirRequest.fullURLString stringByAppendingString:objectName]];
      }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark - FTP specifics
- (void)_listFTPDirectory
{
    if (_FTPListDirRequest)
        return;

    _FTPListDirRequest = [[WRRequestListDirectory alloc] init];
    _FTPListDirRequest.delegate = self;
    _FTPListDirRequest.hostname = _ftpServerAddress;
    _FTPListDirRequest.username = _ftpServerUserName;
    _FTPListDirRequest.password = _ftpServerPassword;
    _FTPListDirRequest.path = _ftpServerPath;
    _FTPListDirRequest.passive = YES;

    [_FTPListDirRequest start];
}

- (NSString *)_credentials
{
    NSString * cred;

    if (_ftpServerUserName.length > 0) {
        if (_ftpServerPassword.length > 0)
            cred = [NSString stringWithFormat:@"%@:%@@", _ftpServerUserName, _ftpServerPassword];
        else
            cred = [NSString stringWithFormat:@"%@@", _ftpServerPassword];
    } else
        cred = @"";

    return [cred stringByStandardizingPath];
}

- (void)_downloadFTPFile:(NSString *)fileName
{
    NSURL *URLToQueue = [NSURL URLWithString:[[@"ftp" stringByAppendingFormat:@"://%@%@/%@/%@", [self _credentials], _ftpServerAddress, _ftpServerPath, fileName] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

    [[(VLCAppDelegate*)[UIApplication sharedApplication].delegate downloadViewController] addURLToDownloadList:URLToQueue fileNameOfMedia:nil];
}

- (void)_downloadUPNPFile:(NSURL *)url fileNameOfMedia:(NSString*) fileName;
{
    fileName = [[fileName stringByAppendingString:@"."] stringByAppendingString:[[url absoluteString] pathExtension]];
    [[(VLCAppDelegate*)[UIApplication sharedApplication].delegate downloadViewController] addURLToDownloadList:url fileNameOfMedia:fileName];
}

- (void)requestCompleted:(WRRequest *)request
{
    if (request == _FTPListDirRequest) {
        NSMutableArray *filteredList = [[NSMutableArray alloc] init];
        NSArray *rawList = [(WRRequestListDirectory*)request filesInfo];
        NSUInteger count = rawList.count;

        for (NSUInteger x = 0; x < count; x++) {
            if (![[rawList[x] objectForKey:(id)kCFFTPResourceName] hasPrefix:@"."])
                [filteredList addObject:rawList[x]];
        }

        _objectList = [NSArray arrayWithArray:filteredList];
        [self.tableView reloadData];
    } else
        APLog(@"unknown request %@ completed", request);
}

- (void)requestFailed:(WRRequest *)request
{
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"ERROR_NUMBER", @""), request.error.errorCode] message:request.error.message delegate:self cancelButtonTitle:NSLocalizedString(@"BUTTON_CANCEL", @"") otherButtonTitles:nil];
    [alert show];

    APLog(@"request %@ failed with error %i", request, request.error.errorCode);
}

#pragma mark - VLCLocalNetworkListCell delegation
- (void)triggerDownloadForCell:(VLCLocalNetworkListCell *)cell
{
    if (_serverType == kVLCServerTypeUPNP) {
        MediaServer1ItemObject *item;
        if ([self.searchDisplayController isActive])
            item = _searchData[[self.searchDisplayController.searchResultsTableView indexPathForCell:cell].row];
        else
            item = _mutableObjectList[[self.tableView indexPathForCell:cell].row];

        MediaServer1ItemRes *resource = nil;
        NSEnumerator *e = [[item resources] objectEnumerator];
        NSURL *itemURL;
        while((resource = (MediaServer1ItemRes*)[e nextObject])){
            itemURL = [NSURL URLWithString:[[item uri] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        }
        if (![[item uri] isSupportedFormat]) {
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FILE_NOT_SUPPORTED", @"") message:[NSString stringWithFormat:NSLocalizedString(@"FILE_NOT_SUPPORTED_LONG", @""), [item uri]] delegate:self cancelButtonTitle:NSLocalizedString(@"BUTTON_CANCEL", @"") otherButtonTitles:nil];
            [alert show];
        } else {
            [self _downloadUPNPFile:itemURL fileNameOfMedia:[item title]];
            [cell.statusLabel showStatusMessage:NSLocalizedString(@"DOWNLOADING", @"")];
        }
    }else if (_serverType == kVLCServerTypeFTP) {
        NSString *objectName;
        NSMutableArray *ObjList = [[NSMutableArray alloc] init];
        [ObjList removeAllObjects];

        if ([self.searchDisplayController isActive]) {
            [ObjList addObjectsFromArray:_searchData];
            objectName = [ObjList[[self.searchDisplayController.searchResultsTableView indexPathForCell:cell].row] objectForKey:(id)kCFFTPResourceName];
        } else {
            [ObjList addObjectsFromArray:_objectList];
            objectName = [ObjList[[self.tableView indexPathForCell:cell].row] objectForKey:(id)kCFFTPResourceName];
        }

        if (![objectName isSupportedFormat]) {
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FILE_NOT_SUPPORTED", @"") message:[NSString stringWithFormat:NSLocalizedString(@"FILE_NOT_SUPPORTED_LONG", @""), objectName] delegate:self cancelButtonTitle:NSLocalizedString(@"BUTTON_CANCEL", @"") otherButtonTitles:nil];
            [alert show];
        } else {
            [self _downloadFTPFile:objectName];
            [cell.statusLabel showStatusMessage:NSLocalizedString(@"DOWNLOADING", @"")];
        }
    }
}

#pragma mark - communication with playback engine
- (void)_openURLStringAndDismiss:(NSString *)url
{
    VLCAppDelegate* appDelegate = [UIApplication sharedApplication].delegate;
    [appDelegate openMovieFromURL:[NSURL URLWithString:url]];
}

#pragma mark - Search Display Controller Delegate

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    MediaServer1BasicObject *item;
    NSInteger listCount = 0;
    [_searchData removeAllObjects];

    if (_serverType == kVLCServerTypeUPNP)
        listCount = _mutableObjectList.count;
    else if (_serverType == kVLCServerTypeFTP)
        listCount = _objectList.count;

    for (int i = 0; i < listCount; i++) {
        NSRange nameRange;
        if (_serverType == kVLCServerTypeUPNP) {
            item = _mutableObjectList[i];
            nameRange = [[item title] rangeOfString:searchString options:NSCaseInsensitiveSearch];
        } else if (_serverType == kVLCServerTypeFTP)
            nameRange = [[_objectList[i] objectForKey:(id)kCFFTPResourceName] rangeOfString:searchString options:NSCaseInsensitiveSearch];

        if (nameRange.location != NSNotFound) {
            if (_serverType == kVLCServerTypeUPNP)
                [_searchData addObject:_mutableObjectList[i]];
            else
                [_searchData addObject:_objectList[i]];
        }
    }

    return YES;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        tableView.rowHeight = 80.0f;
    else
        tableView.rowHeight = 68.0f;

    tableView.backgroundColor = [UIColor blackColor];
}

@end
