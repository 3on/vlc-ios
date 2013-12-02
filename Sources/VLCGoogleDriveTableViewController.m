/*****************************************************************************
 * VLCGoogleDriveTableViewController.m
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

#import "VLCGoogleDriveTableViewController.h"
#import "VLCCloudStorageTableViewCell.h"
#import "VLCGoogleDriveController.h"
#import "VLCAppDelegate.h"
#import "VLCPlaylistViewController.h"
#import "UIBarButtonItem+Theme.h"
#import "VLCGoogleDriveConstants.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "VLCGoogleDriveController.h"

@interface VLCGoogleDriveTableViewController () <VLCCloudStorageTableViewCell>
{
    GTLDriveFile *_selectedFile;
    GTMOAuth2ViewControllerTouch *_authController;

    UIBarButtonItem *_backButton;
    UIBarButtonItem *_backToMenuButton;

    UIBarButtonItem *_numberOfFilesBarButtonItem;
    UIBarButtonItem *_progressBarButtonItem;
    UIBarButtonItem *_downloadingBarLabel;
    UIProgressView *_progressView;

    UIActivityIndicatorView *_activityIndicator;

    BOOL _authorizationInProgress;
    VLCGoogleDriveController *_googleDriveController;
}

@end

@implementation VLCGoogleDriveTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.modalPresentationStyle = UIModalPresentationFormSheet;

    _googleDriveController = [VLCGoogleDriveController sharedInstance];
    _googleDriveController.delegate = self;
    [_googleDriveController startSession];

    _authorizationInProgress = NO;

    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DriveWhite"]];
    self.navigationItem.titleView.contentMode = UIViewContentModeScaleAspectFit;

    _backButton = [UIBarButtonItem themedBackButtonWithTarget:self andSelector:@selector(goBack:)];
    _backToMenuButton = [UIBarButtonItem themedRevealMenuButtonWithTarget:self andSelector:@selector(goBack:)];
    self.navigationItem.leftBarButtonItem = _backToMenuButton;

    self.tableView.rowHeight = [VLCCloudStorageTableViewCell heightOfCell];
    self.tableView.separatorColor = [UIColor colorWithWhite:.122 alpha:1.];
    self.view.backgroundColor = [UIColor colorWithWhite:.122 alpha:1.];

    _numberOfFilesBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"NUM_OF_FILES", @""), 0] style:UIBarButtonItemStylePlain target:nil action:nil];
    [_numberOfFilesBarButtonItem setTitleTextAttributes:@{ UITextAttributeFont : [UIFont systemFontOfSize:11.] } forState:UIControlStateNormal];

    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    _progressBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_progressView];
    _downloadingBarLabel = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"DOWNLOADING",@"") style:UIBarButtonItemStylePlain target:nil action:nil];
    [_downloadingBarLabel setTitleTextAttributes:@{ UITextAttributeFont : [UIFont systemFontOfSize:11.] } forState:UIControlStateNormal];

    self.loginToCloudStorageView.backgroundColor = [UIColor colorWithWhite:.122 alpha:1.];
    [self _setupLogo];

    [self.loginButton setTitle:NSLocalizedString(@"DROPBOX_LOGIN", @"") forState:UIControlStateNormal];

    [self.navigationController.toolbar setBackgroundImage:[UIImage imageNamed:@"sudHeaderBg"] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];

    [self _showProgressInToolbar:NO];

    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicator.hidesWhenStopped = YES;

    [self.view addSubview:_activityIndicator];
}

- (void)_setupLogo
{
    [self.cloudStorageLogo setImage:[UIImage imageNamed:@"driveWhite"]];

    CGRect rect;
    rect.size = [UIImage imageNamed:@"driveWhite"].size;
    rect.origin.x = (self.loginToCloudStorageView.frame.size.width - rect.size.width) / 2;
    rect.origin.y = self.loginButton.frame.origin.y - rect.size.height - 50;

    [self.cloudStorageLogo setFrame:CGRectIntegral(rect)];
}

- (GTMOAuth2ViewControllerTouch *)createAuthController
{
    _authController = [[GTMOAuth2ViewControllerTouch alloc] initWithScope:kGTLAuthScopeDrive
                                                                clientID:kVLCGoogleDriveClientID
                                                            clientSecret:kVLCGoogleDriveClientSecret
                                                        keychainItemName:kKeychainItemName
                                                                delegate:self
                                                        finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    return _authController;
}

- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController finishedWithAuth:(GTMOAuth2Authentication *)authResult error:(NSError *)error
{
    _authorizationInProgress = NO;
    if (error != nil) {
        [self showAlert:NSLocalizedString(@"GDRIVE_AUTHENTICATION_ERROR",nil) message:error.localizedDescription];
        _googleDriveController.driveService.authorizer = nil;
    } else {
        _googleDriveController.driveService.authorizer = authResult;
    }
    [self updateViewAfterSessionChange];
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

- (void)viewWillAppear:(BOOL)animated
{
    self.navigationController.toolbarHidden = NO;
    self.navigationController.toolbar.barStyle = UIBarStyleBlack;
    [self.navigationController.toolbar setBackgroundImage:[UIImage imageNamed:@"bottomBlackBar"] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    [self updateViewAfterSessionChange];
    [super viewWillAppear:animated];

    CGRect aiFrame = _activityIndicator.frame;
    CGSize tvSize = self.tableView.frame.size;
    aiFrame.origin.x = (tvSize.width - aiFrame.size.width) / 2.;
    aiFrame.origin.y = (tvSize.height - aiFrame.size.height) / 2.;
    _activityIndicator.frame = aiFrame;
}

- (void)viewWillDisappear:(BOOL)animated
{
    self.navigationController.toolbarHidden = YES;
    if ((VLCAppDelegate*)[UIApplication sharedApplication].delegate.window.rootViewController.presentedViewController == nil) {
        [_googleDriveController stopSession];
        [self.tableView reloadData];
    }
    [super viewWillDisappear:animated];
}

- (void)_showProgressInToolbar:(BOOL)value
{
    if (!value)
        [self setToolbarItems:@[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], _numberOfFilesBarButtonItem, [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]] animated:YES];
    else {
        _progressView.progress = 0.;
        [self setToolbarItems:@[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], _downloadingBarLabel, _progressBarButtonItem, [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]] animated:YES];
    }
}

- (void)_requestInformationForFiles
{
    [_activityIndicator startAnimating];
    [_googleDriveController requestFileListing];

    self.navigationItem.leftBarButtonItem = _backToMenuButton;
}

#pragma mark - interface interaction

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
        return NO;
    return YES;
}

- (IBAction)goBack:(id)sender
{
    [[(VLCAppDelegate*)[UIApplication sharedApplication].delegate revealController] toggleSidebar:![(VLCAppDelegate*)[UIApplication sharedApplication].delegate revealController].sidebarShowing duration:kGHRevealSidebarDefaultAnimationDuration];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _googleDriveController.currentListFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"GoogleDriveCell";

    VLCCloudStorageTableViewCell *cell = (VLCCloudStorageTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
        cell = [VLCCloudStorageTableViewCell cellWithReuseIdentifier:CellIdentifier];

    cell.driveFile = _googleDriveController.currentListFiles[indexPath.row];
    cell.delegate = self;

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = (indexPath.row % 2 == 0)? [UIColor blackColor]: [UIColor colorWithWhite:.122 alpha:1.];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    _selectedFile = _googleDriveController.currentListFiles[indexPath.row];
    [_googleDriveController streamFile:_selectedFile];
    _selectedFile = nil;
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    NSInteger currentOffset = scrollView.contentOffset.y;
    NSInteger maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height;

    if (maximumOffset - currentOffset <= - self.tableView.rowHeight) {
        if (_googleDriveController.hasMoreFiles && !_activityIndicator.isAnimating) {
            [self _requestInformationForFiles];
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
        [_googleDriveController downloadFileToDocumentFolder:_selectedFile];

    _selectedFile = nil;
}

#pragma mark - table view cell delegation


#pragma mark - VLCLocalNetworkListCell delegation
- (void)triggerDownloadForCell:(VLCCloudStorageTableViewCell *)cell
{
    _selectedFile = _googleDriveController.currentListFiles[[self.tableView indexPathForCell:cell].row];

    /* selected item is a proper file, ask the user if s/he wants to download it */
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"DROPBOX_DOWNLOAD", @"") message:[NSString stringWithFormat:NSLocalizedString(@"DROPBOX_DL_LONG", @""), _selectedFile.title, [[UIDevice currentDevice] model]] delegate:self cancelButtonTitle:NSLocalizedString(@"BUTTON_CANCEL", @"") otherButtonTitles:NSLocalizedString(@"BUTTON_DOWNLOAD", @""), nil];
    [alert show];
}

#pragma mark - google drive controller delegate

- (void)mediaListUpdated
{
    [_activityIndicator stopAnimating];

    [self.tableView reloadData];

    NSUInteger count = _googleDriveController.currentListFiles.count;
    if (count == 0)
        _numberOfFilesBarButtonItem.title = NSLocalizedString(@"NO_FILES", @"");
    else if (count != 1)
        _numberOfFilesBarButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"NUM_OF_FILES", @""), count];
    else
        _numberOfFilesBarButtonItem.title = NSLocalizedString(@"ONE_FILE", @"");
}

- (void)operationWithProgressInformationStarted
{
    [self _showProgressInToolbar:YES];
}

- (void)currentProgressInformation:(float)progress
{
    [_progressView setProgress: progress animated:YES];
}

- (void)operationWithProgressInformationStopped
{
    [self _showProgressInToolbar:NO];
}

#pragma mark - communication with app delegate

- (void)updateViewAfterSessionChange
{
    if(_authorizationInProgress) {
        if (self.loginToCloudStorageView.superview)
            [self.loginToCloudStorageView removeFromSuperview];
        return;
    }
    if (![_googleDriveController isAuthorized]) {
        [self _showLoginPanel];
        return;
    } else if (self.loginToCloudStorageView.superview)
        [self.loginToCloudStorageView removeFromSuperview];

    //reload if we didn't come back from streaming
    if([_googleDriveController.currentListFiles count] == 0)
        [self _requestInformationForFiles];
}

#pragma mark - login dialog

- (void)_showLoginPanel
{
    self.loginToCloudStorageView.frame = self.tableView.frame;
    [self.view addSubview:self.loginToCloudStorageView];
}

- (IBAction)loginAction:(id)sender
{
    if (![_googleDriveController isAuthorized]) {
        _authorizationInProgress = YES;
        [self.navigationController pushViewController:[self createAuthController] animated:YES];
    } else {
        [_googleDriveController logout];
    }
}

@end
