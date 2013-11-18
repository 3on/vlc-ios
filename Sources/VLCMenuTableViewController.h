/*****************************************************************************
 * VLCMenuTableViewController.h
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import <UIKit/UIKit.h>

@class VLCSettingsController;
@class IASKAppSettingsViewController;

@interface VLCMenuTableViewController : UIViewController

@property (strong, nonatomic) IASKAppSettingsViewController *settingsViewController;
@property (strong, nonatomic) VLCSettingsController *settingsController;

@property (nonatomic, strong) UITableView *tableView;

- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition;

@end
