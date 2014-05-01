/*****************************************************************************
 * VLCGoogleDriveController.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Carola Nitz <nitz.carola # googlemail.com>
 *          Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCGoogleDriveController.h"
#import "NSString+SupportedMedia.h"
#import "VLCAppDelegate.h"
#import "HTTPMessage.h"

@interface VLCGoogleDriveController ()
{
    GTLDriveFileList *_fileList;
    GTLServiceTicket *_fileListTicket;

    NSArray *_currentFileList;

    NSMutableArray *_listOfGoogleDriveFilesToDownload;
    BOOL _downloadInProgress;

    NSString *_nextPageToken;
    NSString *_folderId;

    CGFloat _averageSpeed;
    NSTimeInterval _startDL;
    NSTimeInterval _lastStatsUpdate;
}

@end

@implementation VLCGoogleDriveController

#pragma mark - session handling

+ (VLCGoogleDriveController *)sharedInstance
{
    static VLCGoogleDriveController *sharedInstance = nil;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init];
    });

    return sharedInstance;
}

- (void)startSession
{
    self.driveService = [[GTLServiceDrive alloc] init];
    self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName clientID:kVLCGoogleDriveClientID clientSecret:kVLCGoogleDriveClientSecret];
}

- (void)stopSession
{
    [_fileListTicket cancelTicket];
    _nextPageToken = nil;
    _currentFileList = nil;
}

- (void)logout
{
    [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
    self.driveService.authorizer = nil;
    _currentFileList = nil;
    if ([self.delegate respondsToSelector:@selector(mediaListUpdated)])
    [self.delegate mediaListUpdated];
}

- (BOOL)isAuthorized
{
    return [((GTMOAuth2Authentication *)self.driveService.authorizer) canAuthorize];;
}

- (void)showAlert:(NSString *)title message:(NSString *)message
{
    UIAlertView *alert;
    alert = [[UIAlertView alloc] initWithTitle: title
                                       message: message
                                      delegate: nil
                             cancelButtonTitle: @"OK"
                             otherButtonTitles: nil];
    [alert show];
}

#pragma mark - file management
- (void)requestDirectoryListingWithFolderId:(NSString *)folderId
{
    if (self.isAuthorized) {
        //we entered a different folder so discard all current files
        if (![folderId isEqualToString:_folderId])
            _currentFileList = nil;
        [self listFilesWithID:folderId];
    }
}

- (BOOL)hasMoreFiles
{
    return _nextPageToken != nil;
}

- (void)downloadFileToDocumentFolder:(GTLDriveFile *)file
{
    if ([file.mimeType isEqualToString:@"application/vnd.google-apps.folder"]) return;

    if (!_listOfGoogleDriveFilesToDownload)
        _listOfGoogleDriveFilesToDownload = [[NSMutableArray alloc] init];

    [_listOfGoogleDriveFilesToDownload addObject:file];

    if ([self.delegate respondsToSelector:@selector(numberOfFilesWaitingToBeDownloadedChanged)])
        [self.delegate numberOfFilesWaitingToBeDownloadedChanged];

    [self _triggerNextDownload];
}

- (void)listFilesWithID:(NSString *)folderId
{
    _fileList = nil;
    _folderId = folderId;
    GTLQueryDrive *query;

    query = [GTLQueryDrive queryForFilesList];
    query.pageToken = _nextPageToken;
    query.maxResults = 100;
    if (![_folderId isEqualToString:@""]) {
        query.q = [NSString stringWithFormat:@"'%@' in parents", [_folderId lastPathComponent]];
    }
    _fileListTicket = [self.driveService executeQuery:query
                          completionHandler:^(GTLServiceTicket *ticket,
                                              GTLDriveFileList *fileList,
                                              NSError *error) {
                              if (error == nil) {
                                  _fileList = fileList;
                                  _nextPageToken = fileList.nextPageToken;
                                  _fileListTicket = nil;
                                  [self _listOfGoodFilesAndFolders];
                              } else {
                                  [self showAlert:NSLocalizedString(@"GDRIVE_ERROR_FETCHING_FILES",nil) message:error.localizedDescription];
                              }
                          }];
}

- (void)_triggerNextDownload
{
    if (_listOfGoogleDriveFilesToDownload.count > 0 && !_downloadInProgress) {
        [self _reallyDownloadFileToDocumentFolder:_listOfGoogleDriveFilesToDownload[0]];
        [_listOfGoogleDriveFilesToDownload removeObjectAtIndex:0];

        if ([self.delegate respondsToSelector:@selector(numberOfFilesWaitingToBeDownloadedChanged)])
            [self.delegate numberOfFilesWaitingToBeDownloadedChanged];
    }
}

- (void)_reallyDownloadFileToDocumentFolder:(GTLDriveFile *)file
{
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *filePath = [searchPaths[0] stringByAppendingFormat:@"/%@", file.originalFilename];

    [self loadFile:file intoPath:filePath];

    if ([self.delegate respondsToSelector:@selector(operationWithProgressInformationStarted)])
        [self.delegate operationWithProgressInformationStarted];

    _downloadInProgress = YES;
}

- (BOOL)_supportedFileExtension:(NSString *)filename
{
    if ([filename isSupportedMediaFormat] || [filename isSupportedAudioMediaFormat] || [filename isSupportedSubtitleFormat])
        return YES;

    return NO;
}

- (void)_listOfGoodFilesAndFolders
{
    NSMutableArray *listOfGoodFilesAndFolders = [[NSMutableArray alloc] init];

    for (GTLDriveFile *driveFile in _fileList.items)
    {
        BOOL isDirectory = [driveFile.mimeType isEqualToString:@"application/vnd.google-apps.folder"];
        BOOL inDirectory = NO;
        if (driveFile.parents.count > 0) {
            GTLDriveParentReference *parent = (GTLDriveParentReference *)driveFile.parents[0];
            //since there is no rootfolder display the files right away
            if (![parent.isRoot boolValue])
                inDirectory = ![parent.identifier isEqualToString:[_folderId lastPathComponent]];
        }
        BOOL supportedFile = [self _supportedFileExtension:[NSString stringWithFormat:@".%@",driveFile.fileExtension]];

        if ((isDirectory || supportedFile) && !inDirectory)
            [listOfGoodFilesAndFolders addObject:driveFile];
    }
    _currentFileList = [_currentFileList count] ? [_currentFileList arrayByAddingObjectsFromArray:listOfGoodFilesAndFolders] : [NSArray arrayWithArray:listOfGoodFilesAndFolders];

    if ([_currentFileList count] <= 10 && [self hasMoreFiles]) {
        [self listFilesWithID:_folderId];
        return;
    }

    APLog(@"found filtered metadata for %lu files", (unsigned long)_currentFileList.count);

    //the files come in a chaotic order so we order alphabetically
     NSArray *sortedArray = [_currentFileList sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *first = [(GTLDriveFile *)a title];
        NSString *second = [(GTLDriveFile *)b title];
        return [first compare:second];
    }];
    _currentFileList = sortedArray;

    if ([self.delegate respondsToSelector:@selector(mediaListUpdated)])
        [self.delegate mediaListUpdated];
}

- (void)loadFile:(GTLDriveFile*)file intoPath:(NSString*)destinationPath
{
    NSString *exportURLStr = file.downloadUrl;

    if ([exportURLStr length] > 0) {
        NSString *suggestedName = file.originalFilename;
        if ([suggestedName length] == 0) {
            suggestedName = file.title;
        }

        NSURL *url = [NSURL URLWithString:exportURLStr];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        GTMHTTPFetcher *fetcher = [GTMHTTPFetcher fetcherWithRequest:request];

        fetcher.authorizer = self.driveService.authorizer;
        fetcher.downloadPath = destinationPath;

        // Fetcher logging can include comments.
        [fetcher setCommentWithFormat:@"Downloading \"%@\"", file.title];
        __weak GTMHTTPFetcher *weakFetcher = fetcher;
        _startDL = [NSDate timeIntervalSinceReferenceDate];
        fetcher.receivedDataBlock = ^(NSData *receivedData) {
            if ((_lastStatsUpdate > 0 && ([NSDate timeIntervalSinceReferenceDate] - _lastStatsUpdate > .5)) || _lastStatsUpdate <= 0) {
                [self calculateRemainingTime:weakFetcher.downloadedLength expectedDownloadSize:[file.fileSize floatValue]];
                _lastStatsUpdate = [NSDate timeIntervalSinceReferenceDate];
            }

            CGFloat progress = (CGFloat)weakFetcher.downloadedLength / (CGFloat)[file.fileSize unsignedLongValue];
            if ([self.delegate respondsToSelector:@selector(currentProgressInformation:)])
                [self.delegate currentProgressInformation:progress];
        };

        [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
            if (error == nil) {
                [self showAlert:NSLocalizedString(@"GDRIVE_DOWNLOAD_SUCCESSFUL_TITLE",nil) message:NSLocalizedString(@"GDRIVE_DOWNLOAD_SUCCESSFUL",nil)];
                [self downloadSucessfull];
            } else {
                [self showAlert:NSLocalizedString(@"GDRIVE_ERROR_DOWNLOADING_FILE_TITLE",nil) message:NSLocalizedString(@"GDRIVE_ERROR_DOWNLOADING_FILE",nil)];
                [self downloadFailedWithError:error];
            }
        }];
    }
}

- (void)calculateRemainingTime:(CGFloat)receivedDataSize expectedDownloadSize:(CGFloat)expectedDownloadSize
{
    CGFloat lastSpeed = receivedDataSize / ([NSDate timeIntervalSinceReferenceDate] - _startDL);
    CGFloat smoothingFactor = 0.005;
    _averageSpeed = isnan(_averageSpeed) ? lastSpeed : smoothingFactor * lastSpeed + (1 - smoothingFactor) * _averageSpeed;

    CGFloat RemainingInSeconds = (expectedDownloadSize - receivedDataSize) / _averageSpeed;

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:RemainingInSeconds];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    NSString  *remaingTime = [formatter stringFromDate:date];
    if ([self.delegate respondsToSelector:@selector(updateRemainingTime:)])
        [self.delegate updateRemainingTime:remaingTime];
}

- (void)downloadSucessfull
{
    /* update library now that we got a file */
    APLog(@"DriveFile download was successful");
    VLCAppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
    [appDelegate performSelectorOnMainThread:@selector(updateMediaList) withObject:nil waitUntilDone:NO];

    if ([self.delegate respondsToSelector:@selector(operationWithProgressInformationStopped)])
        [self.delegate operationWithProgressInformationStopped];
    _downloadInProgress = NO;

    [self _triggerNextDownload];
}

- (void)downloadFailedWithError:(NSError*)error
{
    APLog(@"DriveFile download failed with error %li", (long)error.code);
    if ([self.delegate respondsToSelector:@selector(operationWithProgressInformationStopped)])
        [self.delegate operationWithProgressInformationStopped];
    _downloadInProgress = NO;

    [self _triggerNextDownload];
}

#pragma mark - VLC internal communication and delegate

- (NSArray *)currentListFiles
{
    return _currentFileList;
}

- (NSInteger)numberOfFilesWaitingToBeDownloaded
{
    if (_listOfGoogleDriveFilesToDownload)
        return _listOfGoogleDriveFilesToDownload.count;

    return 0;
}

@end
