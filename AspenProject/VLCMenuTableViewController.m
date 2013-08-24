//
//  VLCMenuTableViewController.m
//  VLC for iOS
//
//  Created by Felix Paul Kühne on 10.08.13.
//  Copyright (c) 2013 VideoLAN. All rights reserved.
//
//  Refer to the COPYING file of the official project for license.
//

#import "VLCMenuTableViewController.h"
#import "GHRevealViewController.h"
#import "GHMenuCell.h"
#import "Reachability.h"
#import <QuartzCore/QuartzCore.h>
#import "VLCWiFiUploadTableViewCell.h"
#import "VLCHTTPUploaderController.h"
#import "VLCAppDelegate.h"
#import "HTTPServer.h"
#import "IASKAppSettingsViewController.h"
#import "GHRevealViewController.h"
#import "VLCLocalServerListViewController.h"
#import "VLCOpenNetworkStreamViewController.h"
#import "VLCSettingsController.h"
#import "UINavigationController+Theme.h"
#import "UIBarButtonItem+Theme.h"
#import "VLCAboutViewController.h"
#import "VLCPlaylistViewController.h"
#import "VLCBugreporter.h"

@interface VLCMenuTableViewController () <UITableViewDataSource, UITableViewDelegate>
{
    NSArray *_sectionHeaderTexts;
    NSArray *_menuItemsSectionOne;
    NSArray *_menuItemsSectionTwo;
    NSArray *_menuItemsSectionThree;

    UILabel *_uploadLocationLabel;
    UIButton *_uploadButton;
    Reachability *_reachability;
}

@property (nonatomic) VLCHTTPUploaderController *uploadController;
@property (nonatomic) VLCAppDelegate *appDelegate;
@property (nonatomic) GHRevealViewController *revealController;

@end

@implementation VLCMenuTableViewController

- (void)dealloc
{
    [_reachability stopNotifier];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.frame = CGRectMake(0.0f, 0.0f, kGHRevealSidebarWidth, CGRectGetHeight(self.view.bounds));
	self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;

    _sectionHeaderTexts = @[@"SECTION_HEADER_LIBRARY", @"SECTION_HEADER_NETWORK", @"Settings"];
    _menuItemsSectionOne = @[@"LIBRARY_ALL_FILES", @"LIBRARY_MUSIC", @"LIBRARY_SERIES"];
    _menuItemsSectionTwo = @[@"LOCAL_NETWORK", @"OPEN_NETWORK", @"DOWNLOAD_FROM_HTTP", @"WiFi Upload", @"Dropbox"];
    _menuItemsSectionThree = @[@"Settings", @"ABOUT_APP"];

    if (SYSTEM_RUNS_IN_THE_FUTURE)
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0f, 44.0f + 20.0f, kGHRevealSidebarWidth, CGRectGetHeight(self.view.bounds) - (44.0f + 20.0f)) style:UITableViewStylePlain];
    else
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0f, 44.0f, kGHRevealSidebarWidth, CGRectGetHeight(self.view.bounds) - 44.0f) style:UITableViewStylePlain];
	_tableView.delegate = self;
	_tableView.dataSource = self;
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
	_tableView.backgroundColor = [UIColor colorWithRed:(43.0f/255.0f) green:(43.0f/255.0f) blue:(43.0f/255.0f) alpha:1.0f];
	_tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = [VLCWiFiUploadTableViewCell heightOfCell];

    self.view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, kGHRevealSidebarWidth, CGRectGetHeight(self.view.bounds))];
    [self.view addSubview:_tableView];

    if (SYSTEM_RUNS_IN_THE_FUTURE) {
        UIView *brandingBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, kGHRevealSidebarWidth, 64.0f)];
        brandingBackgroundView.backgroundColor = [UIColor colorWithRed:0.1608 green:0.1608 blue:0.1608 alpha:1.0000];
        [self.view addSubview:brandingBackgroundView];
    } else {
        UIImageView *brandingBackgroundImageView;
        brandingBackgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, kGHRevealSidebarWidth, 44.0f)];
        brandingBackgroundImageView.contentMode = UIViewContentModeScaleToFill;
        brandingBackgroundImageView.image = [UIImage imageNamed:@"headerSidebar"];
        [self.view addSubview:brandingBackgroundImageView];
    }
    UIImageView *brandingImageView;
    if (SYSTEM_RUNS_IN_THE_FUTURE)
        brandingImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, kGHRevealSidebarWidth, 44.0f + 40.0f)];
    else
        brandingImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, kGHRevealSidebarWidth, 44.0f)];
    brandingImageView.contentMode = UIViewContentModeCenter;
    brandingImageView.image = [UIImage imageNamed:@"title"];
    [self.view addSubview:brandingImageView];

    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];

    _reachability = [Reachability reachabilityForLocalWiFi];
    [_reachability startNotifier];

    [self netReachabilityChanged:nil];

    self.appDelegate = [[UIApplication sharedApplication] delegate];
    self.uploadController = self.appDelegate.uploadController;
    self.revealController = self.appDelegate.revealController;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(netReachabilityChanged:) name:kReachabilityChangedNotification object:nil];

    BOOL isHTTPServerOn = [[NSUserDefaults standardUserDefaults] boolForKey:kVLCSettingSaveHTTPUploadServerStatus];
    [self.uploadController changeHTTPServerState:isHTTPServerOn];
    [self updateHTTPServerAddress];
}

- (void)viewWillAppear:(BOOL)animated {
	self.view.frame = CGRectMake(0.0f, 0.0f,kGHRevealSidebarWidth, CGRectGetHeight(self.view.bounds));
}

- (void)netReachabilityChanged:(NSNotification *)notification
{
    if (_reachability.currentReachabilityStatus == ReachableViaWiFi) {
        _uploadButton.enabled = YES;
        _uploadLocationLabel.text = NSLocalizedString(@"HTTP_UPLOAD_SERVER_OFF", @"");
    } else {
        _uploadButton.enabled = NO;
        [_uploadButton setImage:[UIImage imageNamed:@"WiFi-off"] forState:UIControlStateNormal];
        _uploadLocationLabel.text = NSLocalizedString(@"HTTP_UPLOAD_NO_CONNECTIVITY", @"");
        [self.uploadController changeHTTPServerState:NO];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
	return (orientation == UIInterfaceOrientationPortraitUpsideDown)
    ? (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    : YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) // media
        return _menuItemsSectionOne.count;
    else if (section == 1) // network
        return _menuItemsSectionTwo.count;
    else if (section == 2) // settings & co
        return _menuItemsSectionThree.count;
    else
        return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"VLCMenuCell";
    static NSString *WiFiCellIdentifier = @"VLCMenuWiFiCell";

    NSString *title;
    if (indexPath.section == 0)
        title = NSLocalizedString(_menuItemsSectionOne[indexPath.row], @"");
    else if(indexPath.section == 1)
        title = NSLocalizedString(_menuItemsSectionTwo[indexPath.row], @"");
    else if(indexPath.section == 2)
        title = NSLocalizedString(_menuItemsSectionThree[indexPath.row], @"");

    UITableViewCell *cell;

    if ([title isEqualToString:@"WiFi Upload"]) {
        cell = (VLCWiFiUploadTableViewCell *)[tableView dequeueReusableCellWithIdentifier:WiFiCellIdentifier];
        if (cell == nil)
            cell = [VLCWiFiUploadTableViewCell cellWithReuseIdentifier:WiFiCellIdentifier];
    } else {
        cell = (GHMenuCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil)
            cell = [[GHMenuCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    if ([title isEqualToString:@"Dropbox"]) {
        cell.imageView.image = [UIImage imageNamed:@"dropboxLabel"];
        cell.textLabel.text = title;
    } else if ([title isEqualToString:@"WiFi Upload"]) {
        _uploadLocationLabel = [(VLCWiFiUploadTableViewCell*)cell uploadAddressLabel];
        _uploadButton = [(VLCWiFiUploadTableViewCell*)cell serverOnButton];
        [_uploadButton addTarget:self action:@selector(toggleHTTPServer:) forControlEvents:UIControlEventTouchUpInside];
    } else
        cell.textLabel.text = title;

    return cell;
}

#pragma mark - tv delegate
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section < 3)
        return 21.f;
    return 0.;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSObject *headerText = NSLocalizedString(_sectionHeaderTexts[section], @"");
	UIView *headerView = nil;
	if (headerText != [NSNull null]) {
		headerView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [UIScreen mainScreen].bounds.size.height, 21.0f)];
		CAGradientLayer *gradient = [CAGradientLayer layer];
		gradient.frame = headerView.bounds;
		gradient.colors = @[
                      (id)[UIColor colorWithRed:(66.0f/255.0f) green:(66.0f/255.0f) blue:(66.0f/255.0f) alpha:1.0f].CGColor,
                      (id)[UIColor colorWithRed:(56.0f/255.0f) green:(56.0f/255.0f) blue:(56.0f/255.0f) alpha:1.0f].CGColor,
                      ];
		[headerView.layer insertSublayer:gradient atIndex:0];

		UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectInset(headerView.bounds, 12.0f, 5.0f)];
		textLabel.text = (NSString *) headerText;
		textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:([UIFont systemFontSize] * 0.8f)];
		textLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
		textLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.25f];
		textLabel.textColor = [UIColor colorWithRed:(118.0f/255.0f) green:(118.0f/255.0f) blue:(118.0f/255.0f) alpha:1.0f];
		textLabel.backgroundColor = [UIColor clearColor];
		[headerView addSubview:textLabel];

		UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [UIScreen mainScreen].bounds.size.height, 1.0f)];
		topLine.backgroundColor = [UIColor colorWithRed:(95.0f/255.0f) green:(95.0f/255.0f) blue:(95.0f/255.0f) alpha:1.0f];
		[headerView addSubview:topLine];

		UIView *bottomLine = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 21.0f, [UIScreen mainScreen].bounds.size.height, 1.0f)];
		bottomLine.backgroundColor = [UIColor colorWithRed:(16.0f/255.0f) green:(16.0f/255.0f) blue:(16.0f/255.0f) alpha:1.0f];
		[headerView addSubview:bottomLine];
	}
	return headerView;
}

#pragma mark - menu implementation

- (void)updateHTTPServerAddress
{
    HTTPServer *server = self.uploadController.httpServer;
    if (server.isRunning) {
        if (server.listeningPort != 80)
            _uploadLocationLabel.text = [NSString stringWithFormat:@"http://%@:%i", [self.uploadController currentIPAddress], server.listeningPort];
        else
            _uploadLocationLabel.text = [NSString stringWithFormat:@"http://%@", [self.uploadController currentIPAddress]];
        [_uploadButton setImage:[UIImage imageNamed:@"WiFi-on"] forState:UIControlStateNormal];
    } else {
        _uploadLocationLabel.text = NSLocalizedString(@"HTTP_UPLOAD_SERVER_OFF", @"");
        [_uploadButton setImage:[UIImage imageNamed:@"WiFi-off"] forState:UIControlStateNormal];
    }
}

- (IBAction)toggleHTTPServer:(UIButton *)sender
{
    BOOL futureHTTPServerState = ![[NSUserDefaults standardUserDefaults] boolForKey:kVLCSettingSaveHTTPUploadServerStatus];

    [[NSUserDefaults standardUserDefaults] setBool:futureHTTPServerState forKey:kVLCSettingSaveHTTPUploadServerStatus];
    [self.uploadController changeHTTPServerState:futureHTTPServerState];
    [self updateHTTPServerAddress];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)_revealItem:(NSUInteger)itemIndex inSection:(NSUInteger)sectionNumber
{
    UIViewController *viewController;
    if (sectionNumber == 1) {
        if (itemIndex == 0)
            viewController = [[VLCLocalServerListViewController alloc] init];
        else if (itemIndex == 1)
            viewController = [[VLCOpenNetworkStreamViewController alloc] init];
        else if (itemIndex == 2)
            viewController = self.appDelegate.downloadViewController;
        else if (itemIndex == 3)
            [self toggleHTTPServer:nil];
        else if (itemIndex == 4)
            viewController = self.appDelegate.dropboxTableViewController;
    } else if (sectionNumber == 2) {
        if (itemIndex == 0) {
            if (!self.settingsController)
                self.settingsController = [[VLCSettingsController alloc] init];

            if (!self.settingsViewController) {
                self.settingsViewController = [[IASKAppSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
                self.settingsController.viewController = self.settingsViewController;
                self.settingsViewController.navigationItem.leftBarButtonItem = [UIBarButtonItem themedRevealMenuButtonWithTarget:self.settingsController.viewController andSelector:@selector(dismiss:)];
            }

            self.settingsViewController.modalPresentationStyle = UIModalPresentationFormSheet;
            self.settingsViewController.delegate = self.settingsController;
            self.settingsViewController.showDoneButton = NO;
            self.settingsViewController.showCreditsFooter = NO;

            viewController = self.settingsController.viewController;
        } else if (itemIndex == 1)
            viewController = [[VLCAboutViewController alloc] init];
    } else {
        viewController = self.appDelegate.playlistViewController;
        [self.appDelegate.playlistViewController setLibraryMode:itemIndex];
    }

    if (!viewController)
        return;

    UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:viewController];
    [navCon loadTheme];

    _revealController.contentViewController = navCon;
	[_revealController toggleSidebar:NO duration:kGHRevealSidebarDefaultAnimationDuration];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[self _revealItem:indexPath.row inSection:indexPath.section];
}

#pragma mark Public Methods
- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition {
	[self.tableView selectRowAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition];
	if (scrollPosition == UITableViewScrollPositionNone)
		[self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];

    [self _revealItem:indexPath.row inSection:indexPath.section];
}

#pragma mark - shake to support

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake)
        [[VLCBugreporter sharedInstance] handleBugreportRequest];
}

@end
