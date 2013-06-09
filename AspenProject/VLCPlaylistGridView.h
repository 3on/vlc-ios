//
//  VLCGridViewCell.h
//  AspenProject
//
//  Created by Felix Paul Kühne on 11.04.13.
//  Copyright (c) 2013 VideoLAN. All rights reserved.
//

#import "VLCLinearProgressIndicator.h"
#import "AQGridViewCell.h"

@class AQGridView;
@interface VLCPlaylistGridView : AQGridViewCell

@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, strong) IBOutlet UIImageView *thumbnailView;
@property (nonatomic, strong) IBOutlet VLCLinearProgressIndicator *progressView;
@property (nonatomic, strong) IBOutlet UIButton *removeMediaButton;
@property (nonatomic, strong) IBOutlet UIImageView *mediaIsUnreadView;

// Temporary workaround: until better solution
@property (nonatomic, weak) AQGridView *gridView;

@property (nonatomic, retain) MLFile *mediaObject;

- (IBAction)removeMedia:(id)sender;
+ (CGSize)preferredSize;

@end
