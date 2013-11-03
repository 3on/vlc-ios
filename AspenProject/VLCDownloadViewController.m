//
//  VLCDownloadViewController.m
//  VLC for iOS
//
//  Created by Felix Paul Kühne on 16.06.13.
//  Copyright (c) 2013 VideoLAN. All rights reserved.
//
//  Refer to the COPYING file of the official project for license.
//

#import "VLCDownloadViewController.h"
#import "VLCHTTPFileDownloader.h"
#import "VLCAppDelegate.h"
#import "UIBarButtonItem+Theme.h"
#import "WhiteRaccoon.h"
#import "NSString+SupportedMedia.h"
#import "VLCHTTPFileDownloader.h"

#define kVLCDownloadViaHTTP 1
#define kVLCDownloadViaFTP 2

@interface VLCDownloadViewController () <WRRequestDelegate, UITableViewDataSource, UITableViewDelegate, VLCHTTPFileDownloader, UITextFieldDelegate>
{
    NSMutableArray *_currentDownloads;
    NSUInteger _currentDownloadType;
    NSString *_humanReadableFilename;
    NSMutableArray *_currentDownloadFilename;
    NSTimeInterval _startDL;

    VLCHTTPFileDownloader *_httpDownloader;

    WRRequestDownload *_FTPDownloadRequest;
    NSTimeInterval _lastStatsUpdate;
}
@end

@implementation VLCDownloadViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self){
        _currentDownloads = [[NSMutableArray alloc] init];
        _currentDownloadFilename = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.downloadButton setTitle:NSLocalizedString(@"BUTTON_DOWNLOAD",@"") forState:UIControlStateNormal];
    self.navigationItem.leftBarButtonItem = [UIBarButtonItem themedRevealMenuButtonWithTarget:self andSelector:@selector(goBack:)];
    self.title = NSLocalizedString(@"DOWNLOAD_FROM_HTTP", @"");
    self.whatToDownloadHelpLabel.text = [NSString stringWithFormat:NSLocalizedString(@"DOWNLOAD_FROM_HTTP_HELP", @""), [[UIDevice currentDevice] model]];
    self.urlField.delegate = self;
    self.urlField.keyboardType = UIKeyboardTypeURL;

    if (SYSTEM_RUNS_IOS7_OR_LATER)
        self.edgesForExtendedLayout = UIRectEdgeNone;
}

- (void)viewWillAppear:(BOOL)animated
{
    if ([[UIPasteboard generalPasteboard] containsPasteboardTypes:@[@"public.url", @"public.text"]]) {
        NSURL *pasteURL = [[UIPasteboard generalPasteboard] valueForPasteboardType:@"public.url"];
        if (!pasteURL || [[pasteURL absoluteString] isEqualToString:@""]) {
            NSString *pasteString = [[UIPasteboard generalPasteboard] valueForPasteboardType:@"public.text"];
            pasteURL = [NSURL URLWithString:pasteString];
        }

        if (pasteURL && ![[pasteURL scheme] isEqualToString:@""] && ![[pasteURL absoluteString] isEqualToString:@""])
            self.urlField.text = [pasteURL absoluteString];
    }
    [self _updateUI];

    [super viewWillAppear:animated];
}

#pragma mark - UI interaction

- (BOOL)shouldAutorotate
{
    UIInterfaceOrientation toInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
        return NO;
    return YES;
}

- (IBAction)goBack:(id)sender
{
    [[(VLCAppDelegate*)[UIApplication sharedApplication].delegate revealController] toggleSidebar:![(VLCAppDelegate*)[UIApplication sharedApplication].delegate revealController].sidebarShowing duration:kGHRevealSidebarDefaultAnimationDuration];
}

- (IBAction)downloadAction:(id)sender
{
    if ([self.urlField.text length] > 0) {
        NSURL *URLtoSave = [NSURL URLWithString:self.urlField.text];
        if (([URLtoSave.scheme isEqualToString:@"http"] || [URLtoSave.scheme isEqualToString:@"https"] || [URLtoSave.scheme isEqualToString:@"ftp"]) && ![URLtoSave.lastPathComponent.pathExtension isEqualToString:@""]) {
            if ([URLtoSave.lastPathComponent isSupportedFormat]) {
                [_currentDownloads addObject:URLtoSave];
                [_currentDownloadFilename addObject:@""];
                self.urlField.text = @"";
                [self.downloadsTable reloadData];

                [self _triggerNextDownload];
            } else {
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FILE_NOT_SUPPORTED", @"") message:[NSString stringWithFormat:NSLocalizedString(@"FILE_NOT_SUPPORTED_LONG", @""), URLtoSave.lastPathComponent] delegate:self cancelButtonTitle:NSLocalizedString(@"BUTTON_CANCEL", @"") otherButtonTitles:nil];
                [alert show];
            }
        }
    }
}

- (void)_updateUI
{
    if (_currentDownloadType != 0)
        [self downloadStarted];
    else
        [self downloadEnded];

    [self.downloadsTable reloadData];
}

#pragma mark - download management
- (void)_triggerNextDownload
{
    if ([_currentDownloads count] > 0) {
        NSString *downloadScheme = [_currentDownloads[0] scheme];
        if ([downloadScheme isEqualToString:@"http"] || [downloadScheme isEqualToString:@"https"]) {
            if (!_httpDownloader) {
                _httpDownloader = [[VLCHTTPFileDownloader alloc] init];
                _httpDownloader.delegate = self;
            }

            if (!_httpDownloader.downloadInProgress) {
                _currentDownloadType = kVLCDownloadViaHTTP;
                if (![[_currentDownloadFilename objectAtIndex:0] isEqualToString:@""]) {
                    [_httpDownloader downloadFileFromURLwithFileName:[_currentDownloads objectAtIndex:0] fileNameOfMedia:[_currentDownloadFilename objectAtIndex:0]];
                    _humanReadableFilename = [_currentDownloadFilename objectAtIndex:0];
                } else {
                    [_httpDownloader downloadFileFromURL:_currentDownloads[0]];
                    _humanReadableFilename = _httpDownloader.userReadableDownloadName;
                }
                    [_currentDownloads removeObjectAtIndex:0];
                    [_currentDownloadFilename removeObjectAtIndex:0];
            }
        } else if ([downloadScheme isEqualToString:@"ftp"]) {
            _currentDownloadType = kVLCDownloadViaFTP;
            [self _downloadFTPFile:_currentDownloads[0]];
            _humanReadableFilename = [_currentDownloads[0] lastPathComponent];
            [_currentDownloads removeObjectAtIndex:0];
            [_currentDownloadFilename removeObjectAtIndex:0];
        } else
            APLog(@"Unknown download scheme '%@'", downloadScheme);

        [self _updateUI];
    } else
        _currentDownloadType = 0;
}

- (IBAction)cancelDownload:(id)sender
{
    if (_currentDownloadType == kVLCDownloadViaHTTP) {
        if (_httpDownloader.downloadInProgress)
            [_httpDownloader cancelDownload];
    } else if (_currentDownloadType == kVLCDownloadViaFTP) {
        if (_FTPDownloadRequest) {
            NSURL *target = _FTPDownloadRequest.downloadLocation;
            [_FTPDownloadRequest destroy];
            [self requestCompleted:_FTPDownloadRequest];

            /* remove partially downloaded content */
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:target.path])
                [fileManager removeItemAtPath:target.path error:nil];
        }
    }
}

#pragma mark - VLC HTTP Downloader delegate

- (void)downloadStarted
{
    [self.activityIndicator stopAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    self.currentDownloadLabel.text = _humanReadableFilename;
    self.progressView.progress = 0.;
    [self.progressPercent setText:@"0%%"];
    [self.speedRate setText:@"0 Kb/s"];
    [self.timeDL setText:@"00:00:00"];
    self.currentDownloadLabel.hidden = NO;
    self.progressView.hidden = NO;
    self.cancelButton.hidden = NO;
    [self.progressPercent setHidden:NO];
    [self.speedRate setHidden:NO];
    [self.timeDL setHidden:NO];
    _startDL = [NSDate timeIntervalSinceReferenceDate];

    APLog(@"download started");
}

- (void)downloadEnded
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.currentDownloadLabel.hidden = YES;
    self.progressView.hidden = YES;
    self.cancelButton.hidden = YES;
    [self.progressPercent setHidden:YES];
    [self.speedRate setHidden:YES];
    [self.timeDL setHidden:YES];
    _currentDownloadType = 0;
    APLog(@"download ended");

    [self _triggerNextDownload];
}

- (void)downloadFailedWithErrorDescription:(NSString *)description
{
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"DOWNLOAD_FAILED", @"") message:description delegate:self cancelButtonTitle:NSLocalizedString(@"BUTTON_CANCEL", @"") otherButtonTitles:nil];
    [alert show];
}

- (void)progressUpdatedTo:(CGFloat)percentage receivedDataSize:(CGFloat)receivedDataSize  expectedDownloadSize:(CGFloat)expectedDownloadSize
{
    if ((_lastStatsUpdate > 0 && ([NSDate timeIntervalSinceReferenceDate] - _lastStatsUpdate > .5)) || _lastStatsUpdate <= 0) {
        [self.progressPercent setText:[NSString stringWithFormat:@"%.1f%%", percentage*100]];
        [self.timeDL setText:[self calculateRemainingTime:receivedDataSize expectedDownloadSize:expectedDownloadSize]];
        [self.speedRate setText:[self calculateSpeedString:receivedDataSize]];
            _lastStatsUpdate = [NSDate timeIntervalSinceReferenceDate];
    }

    [self.progressView setProgress:percentage animated:YES];
}

- (NSString*)calculateRemainingTime:(CGFloat)receivedDataSize  expectedDownloadSize:(CGFloat)expectedDownloadSize
{
    CGFloat speed = receivedDataSize / ([NSDate timeIntervalSinceReferenceDate] - _startDL);

    CGFloat RemainingInSeconds = (expectedDownloadSize - receivedDataSize)/speed;

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:RemainingInSeconds];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    NSString  *remaingTime = [formatter stringFromDate:date];
    return remaingTime;
}

- (NSString*)calculateSpeedString:(CGFloat)receivedDataSize
{
    CGFloat speed = receivedDataSize / ([NSDate timeIntervalSinceReferenceDate] - _startDL);
    NSString *string = [NSByteCountFormatter stringFromByteCount:speed countStyle:NSByteCountFormatterCountStyleDecimal];
    string = [string stringByAppendingString:@"/s"];
    return string;
}

#pragma mark - ftp networking

- (void)_downloadFTPFile:(NSURL *)URLToFile
{
    if (_FTPDownloadRequest)
        return;

    _FTPDownloadRequest = [[WRRequestDownload alloc] init];
    _FTPDownloadRequest.delegate = self;
    _FTPDownloadRequest.passive = YES;

    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directoryPath = searchPaths[0];
    NSURL *destinationURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", directoryPath, URLToFile.lastPathComponent]];
    _FTPDownloadRequest.downloadLocation = destinationURL;

    [_FTPDownloadRequest startWithFullURL:URLToFile];
}

- (void)requestStarted:(WRRequest *)request
{
    [self downloadStarted];
}

- (void)requestCompleted:(WRRequest *)request
{
    _FTPDownloadRequest = nil;
    [self downloadEnded];
}

- (void)requestFailed:(WRRequest *)request
{
    _FTPDownloadRequest = nil;
    [self downloadEnded];

    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"ERROR_NUMBER", @""), request.error.errorCode] message:request.error.message delegate:self cancelButtonTitle:NSLocalizedString(@"BUTTON_CANCEL", @"") otherButtonTitles:nil];
    [alert show];
}

#pragma mark - table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _currentDownloads.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ScheduledDownloadsCell";

    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:.72 alpha:1.];
    }

    NSInteger row = indexPath.row;
    if ([_currentDownloadFilename[row] isEqualToString:@""])
        cell.textLabel.text = [_currentDownloads[row] lastPathComponent];
    else
        cell.textLabel.text = [_currentDownloadFilename[row] lastPathComponent];

    cell.detailTextLabel.text = [_currentDownloads[row] absoluteString];

    return cell;
}

#pragma mark - table view delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = (indexPath.row % 2 == 0)? [UIColor blackColor]: [UIColor colorWithWhite:.122 alpha:1.];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_currentDownloads removeObjectAtIndex:indexPath.row];
        [_currentDownloadFilename removeObjectAtIndex:indexPath.row];
        [tableView reloadData];
    }
}

#pragma mark - communication with other VLC objects
- (void)addURLToDownloadList:(NSURL *)aURL fileNameOfMedia:(NSString*) fileName
{
    [_currentDownloads addObject:aURL];
    if (!fileName)
        fileName = @"";
    [_currentDownloadFilename addObject:fileName];
    [self.downloadsTable reloadData];
    [self _triggerNextDownload];
}

#pragma mark - text view delegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.urlField resignFirstResponder];
    return NO;
}

@end
