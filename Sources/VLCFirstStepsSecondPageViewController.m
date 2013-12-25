/*****************************************************************************
 * VLCFirstStepsSecondPageViewController.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCFirstStepsSecondPageViewController.h"

@interface VLCFirstStepsSecondPageViewController ()

@end

@implementation VLCFirstStepsSecondPageViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSString *model = [[UIDevice currentDevice] model];
    self.descriptionLabel.text = [NSString stringWithFormat:NSLocalizedString(@"FIRST_STEPS_ITUNES_DETAILS", @""), model, model];
}

- (NSString *)pageTitle
{
    return NSLocalizedString(@"FIRST_STEPS_ITUNES", @"");
}

- (NSUInteger)page
{
    return 2;
}

@end
