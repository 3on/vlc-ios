/*****************************************************************************
 * VLCDropboxTableViewController.h
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *          Fabio Ritrovato <sephiroth87 # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCDropboxController.h"

@interface VLCDropboxTableViewController : UIViewController <VLCDropboxController>

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UIView *loginToDropboxView;
@property (nonatomic, strong) IBOutlet UIButton *loginToDropboxButton;

- (IBAction)loginToDropboxAction:(id)sender;

- (void)updateViewAfterSessionChange;

@end
